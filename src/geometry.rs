use std::f64::consts::PI;

use i_overlay::core::fill_rule::FillRule;
use i_overlay::float::simplify::SimplifyShape;

use crate::{Dash, Envelope, EnvelopeError, EnvelopeInput, Pen, PenSample, Point, Pressure};

const MIN_LENGTH: f64 = 1.0e-12;
const MAX_FLATTEN_DEPTH: u32 = 32;

#[derive(Clone, Copy, Debug)]
struct Vertex {
    point: Point,
    arclength: f64,
}

#[derive(Clone, Copy)]
struct PenParams {
    a: f64,
    b: f64,
    theta: f64,
}

pub(crate) fn build_envelope(input: &EnvelopeInput) -> Result<Envelope, EnvelopeError> {
    validate(input)?;
    let flattened = flatten_path(input);
    if flattened.len() < 2 {
        return Ok(Vec::new());
    }

    let base_runs = input.dash.as_ref().map_or_else(
        || vec![flattened.clone()],
        |dash| dash_path(&flattened, dash),
    );
    let pen = input.pressure.as_ref().map_or_else(
        || input.pen.clone(),
        |pressure| clamp_pen(&input.pen, pressure),
    );
    let mut result = Vec::new();
    if input.dash.is_some() || input.pressure.is_some() {
        for run in base_runs.iter().filter(|run| run.len() >= 2) {
            let pressure_runs = input.pressure.as_ref().map_or_else(
                || vec![run.clone()],
                |pressure| pressure_breakup(run, &input.pen, pressure),
            );
            for pressure_run in pressure_runs.iter().filter(|run| run.len() >= 2) {
                result.extend(outline_open(pressure_run, &pen));
            }
        }
    } else if input.path.closed {
        result.extend(outline_closed(&flattened, &pen));
    } else {
        result.extend(outline_open(&flattened, &pen));
    }
    Ok(result)
}

fn validate(input: &EnvelopeInput) -> Result<(), EnvelopeError> {
    if !input.epsilon.is_finite() || input.epsilon <= 0.0 {
        return Err(EnvelopeError::InvalidInput(
            "epsilon must be finite and positive",
        ));
    }
    if input
        .path
        .segments
        .iter()
        .flat_map(|segment| [segment.p0, segment.p1, segment.p2, segment.p3])
        .flatten()
        .any(|value| !value.is_finite())
    {
        return Err(EnvelopeError::InvalidInput(
            "path coordinates must be finite",
        ));
    }
    if input
        .path
        .segments
        .windows(2)
        .any(|pair| !near(pair[0].p3, pair[1].p0))
    {
        return Err(EnvelopeError::InvalidInput(
            "path segments must be contiguous",
        ));
    }
    let samples = pen_samples(&input.pen);
    if samples.is_empty() {
        return Err(EnvelopeError::InvalidInput(
            "the pen needs at least one sample",
        ));
    }
    if samples.iter().any(|sample| {
        !sample.arclength.is_finite()
            || !sample.a.is_finite()
            || !sample.b.is_finite()
            || !sample.angle.is_finite()
            || sample.a <= 0.0
            || sample.b <= 0.0
    }) {
        return Err(EnvelopeError::InvalidInput(
            "pen values must be finite and axes positive",
        ));
    }
    if samples
        .windows(2)
        .any(|pair| pair[0].arclength > pair[1].arclength)
    {
        return Err(EnvelopeError::InvalidInput(
            "pen samples must be sorted by arclength",
        ));
    }
    if matches!(input.pen, Pen::Calligraphic { angle_offset, .. } if !angle_offset.is_finite()) {
        return Err(EnvelopeError::InvalidInput(
            "the calligraphic angle offset must be finite",
        ));
    }
    if let Some(dash) = &input.dash
        && (dash.lengths.is_empty()
            || dash
                .lengths
                .iter()
                .any(|value| !value.is_finite() || *value <= 0.0)
            || !dash.offset.is_finite()
            || !dash.jitter.is_finite()
            || dash.jitter < 0.0)
    {
        return Err(EnvelopeError::InvalidInput(
            "dash values must be finite and lengths positive",
        ));
    }
    if let Some(pressure) = &input.pressure
        && (!pressure.minimum_axis.is_finite()
            || pressure.minimum_axis <= 0.0
            || !pressure.period.is_finite()
            || pressure.period <= 0.0)
    {
        return Err(EnvelopeError::InvalidInput(
            "pressure minimum axis and period must be finite and positive",
        ));
    }
    Ok(())
}

fn clamp_pen(pen: &Pen, pressure: &Pressure) -> Pen {
    let clamp = |sample: &PenSample| {
        let scale = (pressure.minimum_axis / sample.a.min(sample.b)).max(1.0);
        PenSample {
            a: sample.a * scale,
            b: sample.b * scale,
            ..*sample
        }
    };
    match pen {
        Pen::Explicit(samples) => Pen::Explicit(samples.iter().map(clamp).collect()),
        Pen::Calligraphic {
            samples,
            angle_offset,
        } => Pen::Calligraphic {
            samples: samples.iter().map(clamp).collect(),
            angle_offset: *angle_offset,
        },
    }
}

fn pressure_breakup(path: &[Vertex], pen: &Pen, pressure: &Pressure) -> Vec<Vec<Vertex>> {
    let start = path[0].arclength;
    let end = path.last().unwrap().arclength;
    if end - start <= MIN_LENGTH {
        return Vec::new();
    }
    let step = pressure.period / 24.0;
    let mut rng = XorShift64::new(pressure.seed);
    let phase_offset = rng.next_f64() * pressure.period;
    let mut cuts = vec![start];
    let mut position = start + step;
    while position < end - MIN_LENGTH {
        cuts.push(position);
        position += step;
    }
    cuts.push(end);

    let mut runs = Vec::new();
    let mut current = Vec::new();
    for interval in cuts.windows(2) {
        let midpoint = (interval[0] + interval[1]) / 2.0;
        let params = sample_pen(pen, midpoint, [1.0, 0.0]);
        let requested = params.a.min(params.b);
        let duty = (requested / pressure.minimum_axis).clamp(0.0, 1.0);
        let phase = (midpoint + phase_offset).rem_euclid(pressure.period) / pressure.period;
        if duty >= 1.0 || phase < duty {
            append_interval(path, interval[0], interval[1], &mut current);
        } else if current.len() >= 2 {
            runs.push(std::mem::take(&mut current));
        } else {
            current.clear();
        }
    }
    if current.len() >= 2 {
        runs.push(current);
    }
    runs
}

fn flatten_path(input: &EnvelopeInput) -> Vec<Vertex> {
    let mut points = Vec::new();
    for segment in &input.path.segments {
        if points.last().is_none_or(|point| !near(*point, segment.p0)) {
            points.push(segment.p0);
        }
        flatten_cubic(*segment, input.epsilon, 0, &mut points);
    }
    if input.path.closed && points.len() > 1 && !near(points[0], *points.last().unwrap()) {
        points.push(points[0]);
    }

    let mut arclength = 0.0;
    let mut vertices: Vec<Vertex> = Vec::with_capacity(points.len());
    for point in points {
        if let Some(previous) = vertices.last() {
            arclength += distance(previous.point, point);
        }
        if vertices
            .last()
            .is_none_or(|previous| !near(previous.point, point))
        {
            vertices.push(Vertex { point, arclength });
        }
    }
    refine_for_pen(vertices, &input.pen)
}

fn refine_for_pen(vertices: Vec<Vertex>, pen: &Pen) -> Vec<Vertex> {
    let total = vertices.last().map_or(0.0, |vertex| vertex.arclength);
    let samples = pen_samples(pen);
    let mut cuts = Vec::new();
    for pair in samples.windows(2) {
        let relative_axis_change = ((pair[1].a - pair[0].a).abs() / pair[0].a)
            .max((pair[1].b - pair[0].b).abs() / pair[0].b);
        let angle_change = match pen {
            Pen::Explicit(_) => (pair[1].angle - pair[0].angle).abs(),
            Pen::Calligraphic { .. } => 0.0,
        };
        let divisions = (angle_change / (PI / 16.0))
            .max(relative_axis_change / 0.1)
            .ceil()
            .clamp(1.0, 128.0) as usize;
        for division in 1..divisions {
            let amount = division as f64 / divisions as f64;
            cuts.push(pair[0].arclength + (pair[1].arclength - pair[0].arclength) * amount);
        }
    }
    cuts.extend(samples.iter().map(|sample| sample.arclength));
    cuts.retain(|cut| *cut > MIN_LENGTH && *cut < total - MIN_LENGTH);
    cuts.sort_by(f64::total_cmp);
    cuts.dedup_by(|a, b| (*a - *b).abs() <= MIN_LENGTH);

    let mut refined = vertices.clone();
    refined.extend(cuts.into_iter().map(|cut| vertex_at(&vertices, cut)));
    refined.sort_by(|a, b| a.arclength.total_cmp(&b.arclength));
    refined.dedup_by(|a, b| (a.arclength - b.arclength).abs() <= MIN_LENGTH);
    refined
}

fn flatten_cubic(segment: crate::CubicBezier, epsilon: f64, depth: u32, output: &mut Vec<Point>) {
    let deviation = point_line_distance(segment.p1, segment.p0, segment.p3)
        .max(point_line_distance(segment.p2, segment.p0, segment.p3));
    if deviation <= epsilon || depth >= MAX_FLATTEN_DEPTH {
        output.push(segment.p3);
        return;
    }

    let p01 = midpoint(segment.p0, segment.p1);
    let p12 = midpoint(segment.p1, segment.p2);
    let p23 = midpoint(segment.p2, segment.p3);
    let p012 = midpoint(p01, p12);
    let p123 = midpoint(p12, p23);
    let split = midpoint(p012, p123);
    flatten_cubic(
        crate::CubicBezier {
            p0: segment.p0,
            p1: p01,
            p2: p012,
            p3: split,
        },
        epsilon,
        depth + 1,
        output,
    );
    flatten_cubic(
        crate::CubicBezier {
            p0: split,
            p1: p123,
            p2: p23,
            p3: segment.p3,
        },
        epsilon,
        depth + 1,
        output,
    );
}

fn dash_path(path: &[Vertex], dash: &Dash) -> Vec<Vec<Vertex>> {
    let total = path.last().map_or(0.0, |vertex| vertex.arclength);
    if total <= MIN_LENGTH {
        return Vec::new();
    }
    let mut rng = XorShift64::new(dash.seed);
    let mut index = 0usize;
    let mut on = true;
    let mut remaining = jittered_length(dash.lengths[index], dash.jitter, &mut rng);
    let cycle = dash.lengths.iter().sum::<f64>();
    let mut offset = dash.offset.rem_euclid(cycle);
    while offset >= remaining {
        offset -= remaining;
        index = (index + 1) % dash.lengths.len();
        on = !on;
        remaining = jittered_length(dash.lengths[index], dash.jitter, &mut rng);
    }
    remaining -= offset;

    let mut position = 0.0;
    let mut runs = Vec::new();
    let mut current = Vec::new();
    while position < total - MIN_LENGTH {
        let end = (position + remaining).min(total);
        let consumed = end - position;
        if on {
            append_interval(path, position, end, &mut current);
        }
        position = end;
        remaining -= consumed;
        if remaining <= MIN_LENGTH && position < total - MIN_LENGTH {
            if on && current.len() >= 2 {
                runs.push(std::mem::take(&mut current));
            }
            index = (index + 1) % dash.lengths.len();
            on = !on;
            remaining = jittered_length(dash.lengths[index], dash.jitter, &mut rng);
        }
    }
    if current.len() >= 2 {
        runs.push(current);
    }
    runs
}

fn append_interval(path: &[Vertex], start: f64, end: f64, output: &mut Vec<Vertex>) {
    let start_vertex = vertex_at(path, start);
    if output
        .last()
        .is_none_or(|vertex| !near(vertex.point, start_vertex.point))
    {
        output.push(start_vertex);
    }
    output.extend(path.iter().copied().filter(|vertex| {
        vertex.arclength > start + MIN_LENGTH && vertex.arclength < end - MIN_LENGTH
    }));
    let end_vertex = vertex_at(path, end);
    if output
        .last()
        .is_none_or(|vertex| !near(vertex.point, end_vertex.point))
    {
        output.push(end_vertex);
    }
}

fn vertex_at(path: &[Vertex], arclength: f64) -> Vertex {
    let upper = path.partition_point(|vertex| vertex.arclength < arclength);
    if upper == 0 {
        return path[0];
    }
    if upper >= path.len() {
        return *path.last().unwrap();
    }
    let before = path[upper - 1];
    let after = path[upper];
    let span = after.arclength - before.arclength;
    let amount = if span <= MIN_LENGTH {
        0.0
    } else {
        (arclength - before.arclength) / span
    };
    Vertex {
        point: lerp(before.point, after.point, amount),
        arclength,
    }
}

fn outline_open(path: &[Vertex], pen: &Pen) -> Envelope {
    let tangents = open_tangents(path);
    let params: Vec<_> = path
        .iter()
        .zip(&tangents)
        .map(|(vertex, tangent)| sample_pen(pen, vertex.arclength, *tangent))
        .collect();
    let mut left = Vec::with_capacity(path.len());
    let mut right = Vec::with_capacity(path.len());
    for ((vertex, tangent), params) in path.iter().zip(&tangents).zip(&params) {
        left.push(add(vertex.point, nib_point(*params, left_normal(*tangent))));
        right.push(add(
            vertex.point,
            nib_point(*params, right_normal(*tangent)),
        ));
    }

    let mut contour = left;
    append_cap(
        &mut contour,
        path.last().unwrap().point,
        *tangents.last().unwrap(),
        *params.last().unwrap(),
        true,
    );
    contour.extend(right.iter().rev().skip(1).copied());
    append_cap(&mut contour, path[0].point, tangents[0], params[0], false);
    if signed_area(&contour) < 0.0 {
        contour.reverse();
    }
    let mut contours = vec![contour];
    contours.extend(
        path.iter()
            .zip(params)
            .map(|(vertex, params)| pen_contour(vertex.point, params)),
    );
    clean_contours(contours)
}

fn outline_closed(path: &[Vertex], pen: &Pen) -> Envelope {
    let unique = if near(path[0].point, path.last().unwrap().point) {
        &path[..path.len() - 1]
    } else {
        path
    };
    if unique.len() < 3 {
        return outline_open(path, pen);
    }
    let tangents = closed_tangents(unique);
    let mut left = Vec::with_capacity(unique.len());
    let mut right = Vec::with_capacity(unique.len());
    for (vertex, tangent) in unique.iter().zip(tangents.iter().copied()) {
        let params = sample_pen(pen, vertex.arclength, tangent);
        left.push(add(vertex.point, nib_point(params, left_normal(tangent))));
        right.push(add(vertex.point, nib_point(params, right_normal(tangent))));
    }
    let (mut outer, mut inner) = if signed_area(&left).abs() >= signed_area(&right).abs() {
        (left, right)
    } else {
        (right, left)
    };
    if signed_area(&outer) < 0.0 {
        outer.reverse();
    }
    if signed_area(&inner) > 0.0 {
        inner.reverse();
    }
    let mut contours = vec![outer, inner];
    contours.extend(
        unique
            .iter()
            .zip(tangents.iter().copied())
            .map(|(vertex, tangent)| {
                pen_contour(vertex.point, sample_pen(pen, vertex.arclength, tangent))
            }),
    );
    clean_contours(contours)
}

fn clean_contours(mut contours: Vec<Vec<Point>>) -> Envelope {
    for contour in &mut contours {
        deduplicate(contour);
    }
    let shapes = contours.simplify_shape(FillRule::NonZero);
    shapes
        .into_iter()
        .flatten()
        .filter(|contour| contour.len() >= 3)
        .collect()
}

fn append_cap(
    output: &mut Vec<Point>,
    center: Point,
    tangent: Point,
    params: PenParams,
    forward: bool,
) {
    let tangent_angle = tangent[1].atan2(tangent[0]);
    let start = if forward {
        tangent_angle + PI / 2.0
    } else {
        tangent_angle - PI / 2.0
    };
    let eccentricity = (params.a.max(params.b) / params.a.min(params.b)).sqrt();
    let steps = (8.0 * eccentricity).ceil().clamp(8.0, 32.0) as usize;
    for step in 1..=steps {
        let angle = start - PI * step as f64 / steps as f64;
        output.push(add(center, nib_point(params, [angle.cos(), angle.sin()])));
    }
}

fn pen_contour(center: Point, params: PenParams) -> Vec<Point> {
    let eccentricity = (params.a.max(params.b) / params.a.min(params.b)).sqrt();
    let steps = (16.0 * eccentricity).ceil().clamp(16.0, 64.0) as usize;
    (0..steps)
        .map(|step| {
            let angle = 2.0 * PI * step as f64 / steps as f64;
            add(
                center,
                rotate(
                    [params.a * angle.cos(), params.b * angle.sin()],
                    params.theta,
                ),
            )
        })
        .collect()
}

fn sample_pen(pen: &Pen, arclength: f64, tangent: Point) -> PenParams {
    let samples = pen_samples(pen);
    let upper = samples.partition_point(|sample| sample.arclength < arclength);
    let sample = if upper == 0 {
        samples[0]
    } else if upper >= samples.len() {
        *samples.last().unwrap()
    } else {
        let before = samples[upper - 1];
        let after = samples[upper];
        let span = after.arclength - before.arclength;
        let amount = if span <= MIN_LENGTH {
            0.0
        } else {
            (arclength - before.arclength) / span
        };
        PenSample {
            arclength,
            a: before.a + (after.a - before.a) * amount,
            b: before.b + (after.b - before.b) * amount,
            angle: before.angle + (after.angle - before.angle) * amount,
        }
    };
    let theta = match pen {
        Pen::Explicit(_) => sample.angle,
        Pen::Calligraphic { angle_offset, .. } => tangent[1].atan2(tangent[0]) + angle_offset,
    };
    PenParams {
        a: sample.a,
        b: sample.b,
        theta,
    }
}

fn pen_samples(pen: &Pen) -> &[PenSample] {
    match pen {
        Pen::Explicit(samples) | Pen::Calligraphic { samples, .. } => samples,
    }
}

fn nib_point(params: PenParams, direction: Point) -> Point {
    let local = rotate(direction, -params.theta);
    let scale = 1.0
        / (params.a * params.a * local[0] * local[0] + params.b * params.b * local[1] * local[1])
            .sqrt();
    rotate(
        [
            params.a * params.a * local[0] * scale,
            params.b * params.b * local[1] * scale,
        ],
        params.theta,
    )
}

fn open_tangents(path: &[Vertex]) -> Vec<Point> {
    (0..path.len())
        .map(|index| {
            if index == 0 {
                normalize(sub(path[1].point, path[0].point))
            } else if index + 1 == path.len() {
                normalize(sub(path[index].point, path[index - 1].point))
            } else {
                bisector(
                    sub(path[index].point, path[index - 1].point),
                    sub(path[index + 1].point, path[index].point),
                )
            }
        })
        .collect()
}

fn closed_tangents(path: &[Vertex]) -> Vec<Point> {
    (0..path.len())
        .map(|index| {
            let previous = path[(index + path.len() - 1) % path.len()].point;
            let next = path[(index + 1) % path.len()].point;
            bisector(
                sub(path[index].point, previous),
                sub(next, path[index].point),
            )
        })
        .collect()
}

fn bisector(incoming: Point, outgoing: Point) -> Point {
    let sum = add(normalize(incoming), normalize(outgoing));
    if length(sum) <= MIN_LENGTH {
        normalize(outgoing)
    } else {
        normalize(sum)
    }
}

fn jittered_length(base: f64, jitter: f64, rng: &mut XorShift64) -> f64 {
    (base + jitter * (2.0 * rng.next_f64() - 1.0)).max(MIN_LENGTH)
}

struct XorShift64(u64);

impl XorShift64 {
    fn new(seed: u64) -> Self {
        Self(if seed == 0 {
            0x9e37_79b9_7f4a_7c15
        } else {
            seed
        })
    }

    fn next_f64(&mut self) -> f64 {
        self.0 ^= self.0 << 13;
        self.0 ^= self.0 >> 7;
        self.0 ^= self.0 << 17;
        (self.0 >> 11) as f64 / ((1_u64 << 53) as f64)
    }
}

fn point_line_distance(point: Point, start: Point, end: Point) -> f64 {
    let chord = sub(end, start);
    if length(chord) <= MIN_LENGTH {
        distance(point, start)
    } else {
        ((point[0] - start[0]) * chord[1] - (point[1] - start[1]) * chord[0]).abs() / length(chord)
    }
}

fn deduplicate(points: &mut Vec<Point>) {
    points.dedup_by(|a, b| near(*a, *b));
    if points.len() > 1 && near(points[0], *points.last().unwrap()) {
        points.pop();
    }
}

fn signed_area(points: &[Point]) -> f64 {
    points
        .iter()
        .zip(points.iter().cycle().skip(1))
        .map(|(a, b)| a[0] * b[1] - b[0] * a[1])
        .sum::<f64>()
        / 2.0
}

fn rotate(point: Point, angle: f64) -> Point {
    let (sin, cos) = angle.sin_cos();
    [
        cos * point[0] - sin * point[1],
        sin * point[0] + cos * point[1],
    ]
}

fn left_normal(point: Point) -> Point {
    [-point[1], point[0]]
}
fn right_normal(point: Point) -> Point {
    [point[1], -point[0]]
}
fn add(a: Point, b: Point) -> Point {
    [a[0] + b[0], a[1] + b[1]]
}
fn sub(a: Point, b: Point) -> Point {
    [a[0] - b[0], a[1] - b[1]]
}
fn midpoint(a: Point, b: Point) -> Point {
    [(a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0]
}
fn lerp(a: Point, b: Point, amount: f64) -> Point {
    [a[0] + (b[0] - a[0]) * amount, a[1] + (b[1] - a[1]) * amount]
}
fn length(point: Point) -> f64 {
    point[0].hypot(point[1])
}
fn distance(a: Point, b: Point) -> f64 {
    length(sub(a, b))
}
fn normalize(point: Point) -> Point {
    let magnitude = length(point);
    if magnitude <= MIN_LENGTH {
        [1.0, 0.0]
    } else {
        [point[0] / magnitude, point[1] / magnitude]
    }
}
fn near(a: Point, b: Point) -> bool {
    distance(a, b) <= MIN_LENGTH
}

#[cfg(test)]
mod tests {
    use approx::assert_abs_diff_eq;

    use super::*;
    use crate::{CubicBezier, Path};

    fn line_input(a: f64, b: f64) -> EnvelopeInput {
        EnvelopeInput {
            path: Path {
                segments: vec![CubicBezier {
                    p0: [0.0, 0.0],
                    p1: [10.0 / 3.0, 0.0],
                    p2: [20.0 / 3.0, 0.0],
                    p3: [10.0, 0.0],
                }],
                closed: false,
            },
            pen: Pen::Explicit(vec![PenSample {
                arclength: 0.0,
                a,
                b,
                angle: 0.0,
            }]),
            dash: None,
            pressure: None,
            epsilon: 0.01,
        }
    }

    #[test]
    fn circular_pen_matches_constant_width_line_stroke() {
        let result = build_envelope(&line_input(2.0, 2.0)).unwrap();
        assert_eq!(result.len(), 1);
        let bounds = result[0].iter().fold(
            [
                f64::INFINITY,
                f64::INFINITY,
                f64::NEG_INFINITY,
                f64::NEG_INFINITY,
            ],
            |bounds, point| {
                [
                    bounds[0].min(point[0]),
                    bounds[1].min(point[1]),
                    bounds[2].max(point[0]),
                    bounds[3].max(point[1]),
                ]
            },
        );
        assert_abs_diff_eq!(bounds[0], -2.0, epsilon = 1.0e-9);
        assert_abs_diff_eq!(bounds[1], -2.0, epsilon = 1.0e-9);
        assert_abs_diff_eq!(bounds[2], 12.0, epsilon = 1.0e-9);
        assert_abs_diff_eq!(bounds[3], 2.0, epsilon = 1.0e-9);
    }

    #[test]
    fn nib_point_has_requested_axis_supports() {
        let pen = PenParams {
            a: 3.0,
            b: 1.0,
            theta: PI / 2.0,
        };
        let vertical = nib_point(pen, [0.0, 1.0]);
        let horizontal = nib_point(pen, [1.0, 0.0]);
        assert_abs_diff_eq!(vertical[1], 3.0, epsilon = 1.0e-12);
        assert_abs_diff_eq!(horizontal[0], 1.0, epsilon = 1.0e-12);
    }

    #[test]
    fn rotating_pen_refines_a_straight_path_and_stays_simple() {
        let mut input = line_input(3.0, 0.75);
        input.pen = Pen::Explicit(vec![
            PenSample {
                arclength: 0.0,
                a: 3.0,
                b: 0.75,
                angle: 0.0,
            },
            PenSample {
                arclength: 10.0,
                a: 3.0,
                b: 0.75,
                angle: 2.0 * PI,
            },
        ]);
        let flattened = flatten_path(&input);
        assert!(flattened.len() >= 32);
        let result = build_envelope(&input).unwrap();
        assert!(!result.is_empty());
        assert!(result.iter().all(|contour| is_simple(contour)));
    }

    #[test]
    fn tight_arc_is_cleaned_to_simple_polygons() {
        let mut input = line_input(3.0, 0.6);
        let k = 0.552_284_749_830_793_6;
        input.path.segments = vec![CubicBezier {
            p0: [1.0, 0.0],
            p1: [1.0, k],
            p2: [k, 1.0],
            p3: [0.0, 1.0],
        }];
        input.epsilon = 0.001;
        let result = build_envelope(&input).unwrap();
        assert_eq!(result.len(), 1);
        assert!(is_simple(&result[0]));
    }

    #[test]
    fn closed_path_produces_a_seamless_band() {
        let line = |p0, p3| CubicBezier {
            p0,
            p1: lerp(p0, p3, 1.0 / 3.0),
            p2: lerp(p0, p3, 2.0 / 3.0),
            p3,
        };
        let mut input = line_input(0.5, 0.5);
        input.path = Path {
            segments: vec![
                line([0.0, 0.0], [10.0, 0.0]),
                line([10.0, 0.0], [10.0, 10.0]),
                line([10.0, 10.0], [0.0, 10.0]),
                line([0.0, 10.0], [0.0, 0.0]),
            ],
            closed: true,
        };
        let result = build_envelope(&input).unwrap();
        assert_eq!(result.len(), 2);
        assert!(result.iter().all(|contour| is_simple(contour)));
        assert!(signed_area(&result[0]) * signed_area(&result[1]) < 0.0);
    }

    #[test]
    fn dashes_are_independent_capped_outlines() {
        let mut input = line_input(0.5, 0.5);
        input.dash = Some(Dash {
            lengths: vec![2.0, 1.0],
            offset: 0.0,
            jitter: 0.0,
            seed: 1,
        });
        let result = build_envelope(&input).unwrap();
        assert_eq!(result.len(), 4);
        assert!(result.iter().all(|contour| is_simple(contour)));
    }

    #[test]
    fn light_pressure_uses_minimum_width_with_reduced_ink_duty() {
        let mut input = line_input(0.1, 0.1);
        input.pressure = Some(Pressure {
            minimum_axis: 0.4,
            period: 1.0,
            seed: 9,
        });
        let result = build_envelope(&input).unwrap();
        let ink_area = result
            .iter()
            .map(|contour| signed_area(contour).abs())
            .sum::<f64>();
        let max_height = result
            .iter()
            .flatten()
            .map(|point| point[1].abs())
            .fold(0.0, f64::max);

        assert!(result.len() >= 8);
        assert!(ink_area < 8.0);
        assert_abs_diff_eq!(max_height, 0.4, epsilon = 1.0e-9);
    }

    fn is_simple(contour: &[Point]) -> bool {
        let edge_count = contour.len();
        for first in 0..edge_count {
            let a = contour[first];
            let b = contour[(first + 1) % edge_count];
            for second in first + 1..edge_count {
                if second == first
                    || second == first + 1
                    || (first == 0 && second + 1 == edge_count)
                {
                    continue;
                }
                let c = contour[second];
                let d = contour[(second + 1) % edge_count];
                if proper_intersection(a, b, c, d) {
                    return false;
                }
            }
        }
        true
    }

    fn proper_intersection(a: Point, b: Point, c: Point, d: Point) -> bool {
        fn side(a: Point, b: Point, p: Point) -> f64 {
            (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])
        }
        side(a, b, c) * side(a, b, d) < 0.0 && side(c, d, a) * side(c, d, b) < 0.0
    }
}
