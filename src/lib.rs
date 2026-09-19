mod geometry;

use serde::{Deserialize, Serialize};

pub type Point = [f64; 2];
pub type Envelope = Vec<Vec<Point>>;
pub type ProjectedPaths = Vec<Vec<Point>>;

#[derive(Clone, Copy, Debug, Deserialize, PartialEq, Serialize)]
pub enum LinePattern {
    Outline,
    Striped(u64),
    LitHatch {
        light: [f64; 3],
        count: usize,
        length: f64,
        crosshatch: f64,
        seed: u64,
    },
}

#[derive(Clone, Copy, Debug, Deserialize, PartialEq, Serialize)]
pub enum PointDistribution {
    Random,
    Fibonacci,
}

#[derive(Clone, Copy, Debug, Deserialize, PartialEq, Serialize)]
pub enum SpherePattern {
    Outline,
    LatLng {
        latitudes: i32,
        longitudes: i32,
    },
    RandomEquators {
        seed: u64,
        count: usize,
    },
    RandomCircles {
        seed: u64,
        count: usize,
    },
    LitHatch {
        light: [f64; 3],
        count: usize,
        length: f64,
        crosshatch: f64,
        seed: u64,
    },
    LitStipple {
        light: [f64; 3],
        count: usize,
        min_size: f64,
        max_size: f64,
        gamma: f64,
        distribution: PointDistribution,
        seed: u64,
    },
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub enum LarntShape {
    Sphere {
        center: [f64; 3],
        radius: f64,
        pattern: SpherePattern,
    },
    Cube {
        min: [f64; 3],
        max: [f64; 3],
        pattern: LinePattern,
    },
    Cylinder {
        radius: f64,
        start: [f64; 3],
        end: [f64; 3],
        pattern: LinePattern,
    },
    Cone {
        radius: f64,
        base: [f64; 3],
        apex: [f64; 3],
        pattern: LinePattern,
    },
    Torus {
        center: [f64; 3],
        major_radius: f64,
        minor_radius: f64,
        pattern: LinePattern,
    },
    Tube {
        points: Vec<[f64; 3]>,
        radius: f64,
        sides: usize,
        closed: bool,
        pattern: LinePattern,
    },
    Ellipsoid {
        center: [f64; 3],
        radii: [f64; 3],
        pattern: SpherePattern,
    },
    RoundedPolyhedron {
        vertices: Vec<[f64; 3]>,
        radius: f64,
        detail: usize,
        pattern: LinePattern,
    },
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct LarntScene {
    pub shapes: Vec<LarntShape>,
    pub eye: [f64; 3],
    pub center: [f64; 3],
    pub up: [f64; 3],
    pub width: f64,
    pub height: f64,
    pub fovy: f64,
    pub near: f64,
    pub far: f64,
    pub step: f64,
}

#[derive(Clone, Copy, Debug, Deserialize, PartialEq, Serialize)]
pub struct CubicBezier {
    pub p0: Point,
    pub p1: Point,
    pub p2: Point,
    pub p3: Point,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct Path {
    pub segments: Vec<CubicBezier>,
    pub closed: bool,
}

#[derive(Clone, Copy, Debug, Deserialize, PartialEq, Serialize)]
pub struct PenSample {
    pub arclength: f64,
    pub a: f64,
    pub b: f64,
    pub angle: f64,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub enum Pen {
    Explicit(Vec<PenSample>),
    Calligraphic {
        samples: Vec<PenSample>,
        angle_offset: f64,
    },
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct Dash {
    pub lengths: Vec<f64>,
    pub offset: f64,
    pub jitter: f64,
    pub seed: u64,
}

#[derive(Clone, Copy, Debug, Deserialize, PartialEq, Serialize)]
pub struct Pressure {
    pub minimum_axis: f64,
    pub period: f64,
    pub seed: u64,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct EnvelopeInput {
    pub path: Path,
    pub pen: Pen,
    pub dash: Option<Dash>,
    pub pressure: Option<Pressure>,
    pub epsilon: f64,
}

#[derive(Debug)]
pub enum EnvelopeError {
    Decode(bincode::Error),
    Encode(bincode::Error),
    InvalidInput(&'static str),
}

pub fn envelope_stroke(input: &[u8]) -> Vec<u8> {
    try_envelope_stroke(input).unwrap_or_default()
}

pub fn try_envelope_stroke(input: &[u8]) -> Result<Vec<u8>, EnvelopeError> {
    let request: EnvelopeInput = bincode::deserialize(input).map_err(EnvelopeError::Decode)?;
    let envelope = geometry::build_envelope(&request)?;
    bincode::serialize(&envelope).map_err(EnvelopeError::Encode)
}

pub fn larnt_paths(input: &[u8]) -> Vec<u8> {
    try_larnt_paths(input).unwrap_or_default()
}

pub fn try_larnt_paths(input: &[u8]) -> Result<Vec<u8>, EnvelopeError> {
    let scene: LarntScene = bincode::deserialize(input).map_err(EnvelopeError::Decode)?;
    validate_scene(&scene)?;

    let shapes = scene
        .shapes
        .into_iter()
        .map(shape_to_larnt)
        .collect::<Result<Vec<_>, _>>()?;
    let paths = larnt::render(shapes)
        .eye(vector(scene.eye))
        .center(vector(scene.center))
        .up(vector(scene.up))
        .width(scene.width)
        .height(scene.height)
        .fovy(scene.fovy)
        .near(scene.near)
        .far(scene.far)
        .step(scene.step)
        .call();
    let projected = paths
        .iter_paths()
        .filter(|path| path.len() >= 2)
        .map(|path| path.iter().map(|point| [point.x, point.y]).collect())
        .collect::<ProjectedPaths>();

    bincode::serialize(&projected).map_err(EnvelopeError::Encode)
}

fn vector(point: [f64; 3]) -> larnt::Vector {
    larnt::Vector::new(point[0], point[1], point[2])
}

struct LitSphere {
    sphere: larnt::Sphere,
    light: larnt::Vector,
    count: usize,
    length: f64,
    crosshatch: f64,
    seed: u64,
}

struct StippledSphere {
    sphere: larnt::Sphere,
    light: larnt::Vector,
    count: usize,
    min_size: f64,
    max_size: f64,
    gamma: f64,
    distribution: PointDistribution,
    seed: u64,
}

#[derive(Clone, Copy)]
struct HatchSettings {
    light: larnt::Vector,
    count: usize,
    length: f64,
    crosshatch: f64,
    seed: u64,
}

struct LitAxialSurface {
    base: larnt::Primitive,
    start: larnt::Vector,
    end: larnt::Vector,
    radius: f64,
    cone: bool,
    hatch: HatchSettings,
}

struct LitTorus {
    mesh: larnt::Mesh,
    center: larnt::Vector,
    major_radius: f64,
    minor_radius: f64,
    hatch: HatchSettings,
}

#[derive(Clone, Copy)]
struct TubeFrame {
    center: larnt::Vector,
    normal: larnt::Vector,
    binormal: larnt::Vector,
}

struct TubeSurface {
    mesh: larnt::Mesh,
    frames: Vec<TubeFrame>,
    radius: f64,
    sides: usize,
    closed: bool,
    pattern: LinePattern,
}

struct RoundedPolyhedronSurface {
    mesh: larnt::Mesh,
    edge_bands: Vec<Vec<larnt::Vector>>,
    pattern: LinePattern,
}

impl larnt::Shape for RoundedPolyhedronSurface {
    fn bounding_box(&self) -> larnt::BBox {
        larnt::Shape::bounding_box(&self.mesh)
    }

    fn contains(&self, point: larnt::Vector, radius: f64) -> bool {
        larnt::Shape::contains(&self.mesh, point, radius)
    }

    fn intersect(&self, ray: larnt::Ray) -> larnt::Hit {
        larnt::Shape::intersect(&self.mesh, ray)
    }

    fn paths(&self, args: &larnt::RenderArgs) -> larnt::Paths<larnt::Vector> {
        let mut paths = larnt::Shape::paths(&self.mesh, args);
        if matches!(self.pattern, LinePattern::Outline) {
            for band in &self.edge_bands {
                paths.new_path().extend(band.iter().copied());
            }
        }
        paths
    }
}

impl larnt::Shape for TubeSurface {
    fn bounding_box(&self) -> larnt::BBox {
        larnt::Shape::bounding_box(&self.mesh)
    }

    fn contains(&self, point: larnt::Vector, radius: f64) -> bool {
        larnt::Shape::contains(&self.mesh, point, radius)
    }

    fn intersect(&self, ray: larnt::Ray) -> larnt::Hit {
        larnt::Shape::intersect(&self.mesh, ray)
    }

    fn paths(&self, args: &larnt::RenderArgs) -> larnt::Paths<larnt::Vector> {
        let mut paths = larnt::Shape::paths(&self.mesh, args);
        match self.pattern {
            LinePattern::Outline => {}
            LinePattern::Striped(count) => add_tube_rings(
                &mut paths,
                &self.frames,
                self.radius,
                self.sides,
                self.closed,
                count as usize,
                None,
            ),
            LinePattern::LitHatch {
                light,
                count,
                length,
                crosshatch,
                seed,
            } => add_tube_hatches(
                &mut paths,
                &self.frames,
                self.radius,
                self.sides,
                self.closed,
                HatchSettings {
                    light: vector(light),
                    count,
                    length,
                    crosshatch,
                    seed,
                },
            ),
        }
        paths
    }
}

fn build_tube_surface(
    points: Vec<larnt::Vector>,
    radius: f64,
    sides: usize,
    closed: bool,
    pattern: LinePattern,
) -> Result<TubeSurface, EnvelopeError> {
    let minimum_points = if closed { 3 } else { 2 };
    if points.len() < minimum_points
        || !radius.is_finite()
        || radius <= 0.0
        || !(6..=128).contains(&sides)
        || points
            .iter()
            .any(|point| !point.x.is_finite() || !point.y.is_finite() || !point.z.is_finite())
        || points
            .windows(2)
            .any(|pair| pair[0].distance_squared(pair[1]) < 1e-16)
    {
        return Err(EnvelopeError::InvalidInput(
            "tube needs distinct finite points, positive radius, and 6 to 128 sides",
        ));
    }

    if let LinePattern::Striped(count) = pattern
        && (count == 0 || count > 720)
    {
        return Err(EnvelopeError::InvalidInput(
            "tube stripe count must be between 1 and 720",
        ));
    }
    if let LinePattern::LitHatch {
        light,
        count,
        length,
        crosshatch,
        seed,
    } = pattern
    {
        hatch_settings(light, count, length, crosshatch, seed)?;
    }

    let frames = tube_frames(&points, closed);
    let mut vertices = Vec::with_capacity(frames.len() * sides + usize::from(!closed) * 2);
    for frame in &frames {
        for side in 0..sides {
            let angle = std::f64::consts::TAU * side as f64 / sides as f64;
            vertices.push(
                frame
                    .center
                    .add(frame.normal.mul_scalar(radius * angle.cos()))
                    .add(frame.binormal.mul_scalar(radius * angle.sin())),
            );
        }
    }

    let segment_count = if closed {
        frames.len()
    } else {
        frames.len() - 1
    };
    let mut triangles = Vec::with_capacity(segment_count * sides * 6 + sides * 6);
    for ring in 0..segment_count {
        let next_ring = (ring + 1) % frames.len();
        for side in 0..sides {
            let next_side = (side + 1) % sides;
            let a = ring * sides + side;
            let b = next_ring * sides + side;
            let c = next_ring * sides + next_side;
            let d = ring * sides + next_side;
            triangles.extend([a, b, c, a, c, d]);
        }
    }
    if !closed {
        let start_center = vertices.len();
        vertices.push(frames[0].center);
        let end_center = vertices.len();
        vertices.push(frames[frames.len() - 1].center);
        let end_offset = (frames.len() - 1) * sides;
        for side in 0..sides {
            let next_side = (side + 1) % sides;
            triangles.extend([start_center, next_side, side]);
            triangles.extend([end_center, end_offset + side, end_offset + next_side]);
        }
    }

    let mut mesh = larnt::Mesh::builder(vertices, triangles).build();
    mesh.texture = larnt::MeshTexture::Silhouette(0.0);
    Ok(TubeSurface {
        mesh,
        frames,
        radius,
        sides,
        closed,
        pattern,
    })
}

fn tube_frames(points: &[larnt::Vector], closed: bool) -> Vec<TubeFrame> {
    let tangents = (0..points.len())
        .map(|index| {
            let previous = if index == 0 {
                if closed { points.len() - 1 } else { 0 }
            } else {
                index - 1
            };
            let next = if index + 1 == points.len() {
                if closed { 0 } else { index }
            } else {
                index + 1
            };
            let central = points[next].sub(points[previous]);
            if central.length_squared() > 1e-16 {
                central.normalize()
            } else {
                points[next].sub(points[index]).normalize()
            }
        })
        .collect::<Vec<_>>();

    let mut frames = Vec::with_capacity(points.len());
    let mut normal = tangents[0].cross(tangents[0].min_axis()).normalize();
    for (&center, &tangent) in points.iter().zip(&tangents) {
        let transported = normal.sub(tangent.mul_scalar(normal.dot(tangent)));
        normal = if transported.length_squared() > 1e-16 {
            transported.normalize()
        } else {
            tangent.cross(tangent.min_axis()).normalize()
        };
        frames.push(TubeFrame {
            center,
            normal,
            binormal: tangent.cross(normal).normalize(),
        });
    }
    frames
}

fn tube_frame_at(frames: &[TubeFrame], closed: bool, fraction: f64) -> TubeFrame {
    let span = if closed {
        frames.len() as f64
    } else {
        (frames.len() - 1) as f64
    };
    let position = fraction * span;
    let index = (position.floor() as usize).min(frames.len() - 1);
    let next = if index + 1 == frames.len() {
        if closed { 0 } else { index }
    } else {
        index + 1
    };
    let amount = position - position.floor();
    let center = frames[index]
        .center
        .mul_scalar(1.0 - amount)
        .add(frames[next].center.mul_scalar(amount));
    let normal = frames[index]
        .normal
        .mul_scalar(1.0 - amount)
        .add(frames[next].normal.mul_scalar(amount))
        .normalize();
    let binormal = frames[index]
        .binormal
        .mul_scalar(1.0 - amount)
        .add(frames[next].binormal.mul_scalar(amount))
        .normalize();
    TubeFrame {
        center,
        normal,
        binormal,
    }
}

fn add_tube_rings(
    paths: &mut larnt::Paths<larnt::Vector>,
    frames: &[TubeFrame],
    radius: f64,
    sides: usize,
    closed: bool,
    count: usize,
    lighting: Option<(larnt::Vector, f64, u64)>,
) {
    for ring_index in 0..count {
        let key = lighting.map_or(0, |(_, _, seed)| seed) ^ ring_index as u64;
        let fraction = (ring_index as f64 + 0.5) / count as f64;
        let frame = tube_frame_at(frames, closed, fraction);
        let samples = (sides * 3).max(48);
        let ring = (0..=samples).map(|sample_index| {
            let angle = std::f64::consts::TAU * sample_index as f64 / samples as f64;
            let normal = frame
                .normal
                .mul_scalar(angle.cos())
                .add(frame.binormal.mul_scalar(angle.sin()))
                .normalize();
            let point = frame.center.add(normal.mul_scalar(radius * 1.004));
            (point, normal)
        });
        if let Some((light, minimum, _)) = lighting {
            let threshold = minimum + (1.0 - minimum) * unit_hash(key.rotate_left(29));
            add_thresholded_curve(paths, ring, light, threshold);
        } else {
            paths.new_path().extend(ring.map(|(point, _)| point));
        }
    }
}

fn add_tube_hatches(
    paths: &mut larnt::Paths<larnt::Vector>,
    frames: &[TubeFrame],
    radius: f64,
    sides: usize,
    closed: bool,
    hatch: HatchSettings,
) {
    let light = hatch.light.normalize();
    let ring_count = ((hatch.count as f64).sqrt() * (0.85 + hatch.length)).round() as usize;
    add_tube_rings(
        paths,
        frames,
        radius,
        sides,
        closed,
        ring_count.max(8),
        Some((light, 0.16, hatch.seed)),
    );

    if hatch.crosshatch < 1.0 {
        let rail_count = (ring_count * 2 / 3).max(6);
        for rail_index in 0..rail_count {
            let key = hatch.seed.rotate_left(17) ^ rail_index as u64;
            let angle = std::f64::consts::TAU * (rail_index as f64 + 0.35 * unit_hash(key))
                / rail_count as f64;
            let threshold =
                hatch.crosshatch + (1.0 - hatch.crosshatch) * unit_hash(key.rotate_left(29));
            let mut samples = frames
                .iter()
                .map(|frame| {
                    let normal = frame
                        .normal
                        .mul_scalar(angle.cos())
                        .add(frame.binormal.mul_scalar(angle.sin()))
                        .normalize();
                    (frame.center.add(normal.mul_scalar(radius * 1.004)), normal)
                })
                .collect::<Vec<_>>();
            if closed {
                samples.push(samples[0]);
            }
            add_thresholded_curve(paths, samples, light, threshold);
        }
    }
}

impl larnt::Shape for StippledSphere {
    fn bounding_box(&self) -> larnt::BBox {
        larnt::Shape::bounding_box(&self.sphere)
    }

    fn contains(&self, point: larnt::Vector, radius: f64) -> bool {
        larnt::Shape::contains(&self.sphere, point, radius)
    }

    fn intersect(&self, ray: larnt::Ray) -> larnt::Hit {
        larnt::Shape::intersect(&self.sphere, ray)
    }

    fn paths(&self, args: &larnt::RenderArgs) -> larnt::Paths<larnt::Vector> {
        let mut paths = larnt::Shape::paths(&self.sphere, args);
        let light = self.light.normalize();
        let golden_angle = std::f64::consts::PI * (3.0 - 5.0_f64.sqrt());
        let phase = std::f64::consts::TAU * unit_hash(self.seed);

        for index in 0..self.count {
            let key = index as u64 ^ self.seed;
            let (z, azimuth) = match self.distribution {
                PointDistribution::Random => (
                    1.0 - 2.0 * unit_hash(key),
                    std::f64::consts::TAU * unit_hash(key.rotate_left(21)),
                ),
                PointDistribution::Fibonacci => (
                    1.0 - 2.0 * (index as f64 + 0.5) / self.count as f64,
                    phase + golden_angle * index as f64,
                ),
            };
            let radial = (1.0 - z * z).sqrt();
            let normal = larnt::Vector::new(radial * azimuth.cos(), radial * azimuth.sin(), z);
            let darkness = stipple_tone(lambert_darkness(normal, light));
            if unit_hash(key.rotate_left(42)) > darkness.powf(self.gamma) {
                continue;
            }

            let size = self.min_size + (self.max_size - self.min_size) * darkness.powf(0.55);
            let mut tangent = normal.cross(light);
            if tangent.length_squared() < 1e-12 {
                tangent = normal.cross(normal.min_axis());
            }
            add_surface_hatch(
                &mut paths,
                &self.sphere,
                normal,
                tangent.normalize(),
                size / 2.0,
            );
        }
        paths
    }
}

impl larnt::Shape for LitSphere {
    fn bounding_box(&self) -> larnt::BBox {
        larnt::Shape::bounding_box(&self.sphere)
    }

    fn contains(&self, point: larnt::Vector, radius: f64) -> bool {
        larnt::Shape::contains(&self.sphere, point, radius)
    }

    fn intersect(&self, ray: larnt::Ray) -> larnt::Hit {
        larnt::Shape::intersect(&self.sphere, ray)
    }

    fn paths(&self, args: &larnt::RenderArgs) -> larnt::Paths<larnt::Vector> {
        let mut paths = larnt::Shape::paths(&self.sphere, args);
        let light = self.light.normalize();
        let primary_axis = larnt::Vector::new(0.42, -0.78, 0.46).normalize();
        let primary_count = ((self.count as f64).sqrt() * (0.85 + self.length)).round() as usize;
        add_sphere_hatch_family(
            &mut paths,
            &self.sphere,
            light,
            primary_axis,
            primary_count.max(8),
            0.16,
            self.seed,
        );

        if self.crosshatch < 1.0 {
            let secondary_axis = primary_axis.cross(light).normalize();
            add_sphere_hatch_family(
                &mut paths,
                &self.sphere,
                light,
                secondary_axis,
                (primary_count * 2 / 3).max(6),
                self.crosshatch,
                self.seed.rotate_left(17),
            );
        }
        paths
    }
}

impl larnt::Shape for LitAxialSurface {
    fn bounding_box(&self) -> larnt::BBox {
        larnt::Shape::bounding_box(&self.base)
    }

    fn contains(&self, point: larnt::Vector, radius: f64) -> bool {
        larnt::Shape::contains(&self.base, point, radius)
    }

    fn intersect(&self, ray: larnt::Ray) -> larnt::Hit {
        larnt::Shape::intersect(&self.base, ray)
    }

    fn paths(&self, args: &larnt::RenderArgs) -> larnt::Paths<larnt::Vector> {
        let mut paths = larnt::Shape::paths(&self.base, args);
        add_axial_hatches(
            &mut paths,
            self.start,
            self.end,
            self.radius,
            self.cone,
            self.hatch,
        );
        paths
    }
}

impl larnt::Shape for LitTorus {
    fn bounding_box(&self) -> larnt::BBox {
        larnt::Shape::bounding_box(&self.mesh)
    }

    fn contains(&self, point: larnt::Vector, radius: f64) -> bool {
        larnt::Shape::contains(&self.mesh, point, radius)
    }

    fn intersect(&self, ray: larnt::Ray) -> larnt::Hit {
        larnt::Shape::intersect(&self.mesh, ray)
    }

    fn paths(&self, args: &larnt::RenderArgs) -> larnt::Paths<larnt::Vector> {
        let mut paths = larnt::Shape::paths(&self.mesh, args);
        add_torus_hatches(
            &mut paths,
            self.center,
            self.major_radius,
            self.minor_radius,
            self.hatch,
        );
        paths
    }
}

fn add_sphere_hatch_family(
    paths: &mut larnt::Paths<larnt::Vector>,
    sphere: &larnt::Sphere,
    light: larnt::Vector,
    axis: larnt::Vector,
    line_count: usize,
    minimum_darkness: f64,
    seed: u64,
) {
    let axis = axis.normalize();
    let u = axis.cross(axis.min_axis()).normalize();
    let v = axis.cross(u).normalize();
    let samples = 128;

    for line_index in 0..line_count {
        let key = line_index as u64 ^ seed;
        let fraction = (line_index as f64 + 0.5) / line_count as f64;
        let jitter = (unit_hash(key) - 0.5) * 0.7 / line_count as f64;
        let offset = (-0.96 + 1.92 * (fraction + jitter)).clamp(-0.98, 0.98);
        let ring_radius = (1.0 - offset * offset).sqrt();
        let threshold =
            minimum_darkness + (1.0 - minimum_darkness) * unit_hash(key.rotate_left(29));
        let mut run = Vec::new();

        for sample_index in 0..=samples {
            let angle = std::f64::consts::TAU * sample_index as f64 / samples as f64;
            let normal = axis
                .mul_scalar(offset)
                .add(u.mul_scalar(ring_radius * angle.cos()))
                .add(v.mul_scalar(ring_radius * angle.sin()));
            if lambert_darkness(normal, light) >= threshold {
                run.push(normal.mul_scalar(sphere.radius).add(sphere.center));
            } else if run.len() >= 2 {
                paths.new_path().extend(std::mem::take(&mut run));
            } else {
                run.clear();
            }
        }
        if run.len() >= 2 {
            paths.new_path().extend(run);
        }
    }
}

fn add_axial_hatches(
    paths: &mut larnt::Paths<larnt::Vector>,
    start: larnt::Vector,
    end: larnt::Vector,
    radius: f64,
    cone: bool,
    hatch: HatchSettings,
) {
    let axis = end.sub(start);
    let height = axis.length();
    let axis = axis.normalize();
    let u = axis.cross(axis.min_axis()).normalize();
    let v = axis.cross(u).normalize();
    let light = hatch.light.normalize();
    let ring_count = ((hatch.count as f64).sqrt() * (0.85 + hatch.length)).round() as usize;

    for ring_index in 0..ring_count.max(8) {
        let key = ring_index as u64 ^ hatch.seed;
        let fraction = (ring_index as f64 + 0.5) / ring_count as f64;
        let axial =
            (fraction + (unit_hash(key) - 0.5) * 0.55 / ring_count as f64).clamp(0.015, 0.985);
        let ring_radius = if cone { radius * (1.0 - axial) } else { radius };
        let threshold = 0.16 + 0.84 * unit_hash(key.rotate_left(29));
        let samples = (96.0 * (0.8 + hatch.length)).round() as usize;
        add_thresholded_curve(
            paths,
            (0..=samples).map(|sample_index| {
                let angle = std::f64::consts::TAU * sample_index as f64 / samples as f64;
                let radial = u.mul_scalar(angle.cos()).add(v.mul_scalar(angle.sin()));
                let normal = if cone {
                    radial
                        .mul_scalar(height)
                        .add(axis.mul_scalar(radius))
                        .normalize()
                } else {
                    radial
                };
                let point = start
                    .add(axis.mul_scalar(height * axial))
                    .add(radial.mul_scalar(ring_radius))
                    .add(normal.mul_scalar(radius * 0.004));
                (point, normal)
            }),
            light,
            threshold,
        );
    }

    if hatch.crosshatch < 1.0 {
        let generator_count = (ring_count * 2 / 3).max(6);
        for generator_index in 0..generator_count {
            let key = generator_index as u64 ^ hatch.seed.rotate_left(17);
            let angle = std::f64::consts::TAU * (generator_index as f64 + 0.35 * unit_hash(key))
                / generator_count as f64;
            let radial = u.mul_scalar(angle.cos()).add(v.mul_scalar(angle.sin()));
            let normal = if cone {
                radial
                    .mul_scalar(height)
                    .add(axis.mul_scalar(radius))
                    .normalize()
            } else {
                radial
            };
            let threshold =
                hatch.crosshatch + (1.0 - hatch.crosshatch) * unit_hash(key.rotate_left(29));
            add_thresholded_curve(
                paths,
                (0..=48).map(|sample_index| {
                    let axial = sample_index as f64 / 48.0;
                    let local_radius = if cone { radius * (1.0 - axial) } else { radius };
                    (
                        start
                            .add(axis.mul_scalar(height * axial))
                            .add(radial.mul_scalar(local_radius))
                            .add(normal.mul_scalar(radius * 0.004)),
                        normal,
                    )
                }),
                light,
                threshold,
            );
        }
    }
}

fn add_torus_hatches(
    paths: &mut larnt::Paths<larnt::Vector>,
    center: larnt::Vector,
    major_radius: f64,
    minor_radius: f64,
    hatch: HatchSettings,
) {
    let light = hatch.light.normalize();
    let ring_count = ((hatch.count as f64).sqrt() * (0.85 + hatch.length)).round() as usize;

    for ring_index in 0..ring_count.max(8) {
        let key = ring_index as u64 ^ hatch.seed;
        let v = std::f64::consts::TAU * (ring_index as f64 + 0.5 + (unit_hash(key) - 0.5) * 0.5)
            / ring_count as f64;
        let threshold = 0.16 + 0.84 * unit_hash(key.rotate_left(29));
        add_thresholded_curve(
            paths,
            (0..=128).map(|sample_index| {
                let u = std::f64::consts::TAU * sample_index as f64 / 128.0;
                torus_sample(center, major_radius, minor_radius, u, v)
            }),
            light,
            threshold,
        );
    }

    if hatch.crosshatch < 1.0 {
        let meridian_count = (ring_count * 2 / 3).max(6);
        for meridian_index in 0..meridian_count {
            let key = meridian_index as u64 ^ hatch.seed.rotate_left(17);
            let u = std::f64::consts::TAU * (meridian_index as f64 + 0.35 * unit_hash(key))
                / meridian_count as f64;
            let threshold =
                hatch.crosshatch + (1.0 - hatch.crosshatch) * unit_hash(key.rotate_left(29));
            add_thresholded_curve(
                paths,
                (0..=64).map(|sample_index| {
                    let v = std::f64::consts::TAU * sample_index as f64 / 64.0;
                    torus_sample(center, major_radius, minor_radius, u, v)
                }),
                light,
                threshold,
            );
        }
    }
}

fn torus_sample(
    center: larnt::Vector,
    major_radius: f64,
    minor_radius: f64,
    u: f64,
    v: f64,
) -> (larnt::Vector, larnt::Vector) {
    let normal = larnt::Vector::new(v.cos() * u.cos(), v.cos() * u.sin(), v.sin());
    let point = larnt::Vector::new(
        (major_radius + minor_radius * v.cos()) * u.cos(),
        (major_radius + minor_radius * v.cos()) * u.sin(),
        minor_radius * v.sin(),
    )
    .add(center)
    .add(normal.mul_scalar(minor_radius * 0.004));
    (point, normal)
}

fn add_thresholded_curve(
    paths: &mut larnt::Paths<larnt::Vector>,
    samples: impl IntoIterator<Item = (larnt::Vector, larnt::Vector)>,
    light: larnt::Vector,
    threshold: f64,
) {
    let mut run = Vec::new();
    for (point, normal) in samples {
        if lambert_darkness(normal, light) >= threshold {
            run.push(point);
        } else if run.len() >= 2 {
            paths.new_path().extend(std::mem::take(&mut run));
        } else {
            run.clear();
        }
    }
    if run.len() >= 2 {
        paths.new_path().extend(run);
    }
}

fn lambert_darkness(normal: larnt::Vector, light: larnt::Vector) -> f64 {
    1.0 - normal.dot(light).clamp(0.0, 1.0)
}

fn stipple_tone(darkness: f64) -> f64 {
    smoothstep(0.38, 0.72, darkness)
}

fn smoothstep(edge0: f64, edge1: f64, value: f64) -> f64 {
    let amount = ((value - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    amount * amount * (3.0 - 2.0 * amount)
}

fn add_surface_hatch(
    paths: &mut larnt::Paths<larnt::Vector>,
    sphere: &larnt::Sphere,
    normal: larnt::Vector,
    tangent: larnt::Vector,
    half_angle: f64,
) {
    let point = |offset: f64| {
        normal
            .add(tangent.mul_scalar(offset))
            .normalize()
            .mul_scalar(sphere.radius)
            .add(sphere.center)
    };
    paths
        .new_path()
        .extend([point(-half_angle), point(0.0), point(half_angle)]);
}

fn unit_hash(mut value: u64) -> f64 {
    value = value.wrapping_add(0x9e3779b97f4a7c15);
    value = (value ^ (value >> 30)).wrapping_mul(0xbf58476d1ce4e5b9);
    value = (value ^ (value >> 27)).wrapping_mul(0x94d049bb133111eb);
    let mixed = value ^ (value >> 31);
    (mixed >> 11) as f64 / (1_u64 << 53) as f64
}

fn line_count(pattern: LinePattern) -> Result<Option<u64>, EnvelopeError> {
    match pattern {
        LinePattern::Outline => Ok(None),
        LinePattern::Striped(count) if count > 0 && count <= 360 => Ok(Some(count)),
        LinePattern::Striped(_) => Err(EnvelopeError::InvalidInput(
            "stripe count must be between 1 and 360",
        )),
        LinePattern::LitHatch { .. } => Err(EnvelopeError::InvalidInput(
            "lighting pattern must be handled by the surface",
        )),
    }
}

fn hatch_settings(
    light: [f64; 3],
    count: usize,
    length: f64,
    crosshatch: f64,
    seed: u64,
) -> Result<HatchSettings, EnvelopeError> {
    if count == 0
        || length <= 0.0
        || !(0.0..=1.0).contains(&crosshatch)
        || vector(light).length_squared() == 0.0
    {
        return Err(EnvelopeError::InvalidInput(
            "invalid lighting-aware hatch pattern",
        ));
    }
    Ok(HatchSettings {
        light: vector(light),
        count,
        length,
        crosshatch,
        seed,
    })
}

fn torus_surface(
    center: larnt::Vector,
    major_radius: f64,
    minor_radius: f64,
    u_steps: usize,
    v_steps: usize,
) -> larnt::ParametricSurface {
    larnt::ParametricSurface::new(
        move |u, v| torus_sample(center, major_radius, minor_radius, u, v).0,
        (0.0, std::f64::consts::TAU),
        (0.0, std::f64::consts::TAU),
        u_steps,
        v_steps,
    )
}

fn rounded_polyhedron_surface(
    vertices: Vec<larnt::Vector>,
    radius: f64,
    detail: usize,
    pattern: LinePattern,
) -> Result<RoundedPolyhedronSurface, EnvelopeError> {
    if vertices.len() < 4
        || !radius.is_finite()
        || radius <= 0.0
        || !(12..=256).contains(&detail)
        || vertices
            .iter()
            .any(|point| !point.x.is_finite() || !point.y.is_finite() || !point.z.is_finite())
    {
        return Err(EnvelopeError::InvalidInput(
            "rounded polyhedron needs at least four finite vertices, positive radius, and detail from 12 to 256",
        ));
    }
    if matches!(pattern, LinePattern::LitHatch { .. }) {
        return Err(EnvelopeError::InvalidInput(
            "rounded polyhedra currently support outline or striped texture",
        ));
    }

    let source_points = vertices
        .iter()
        .map(|point| parry3d_f64::math::Vector::new(point.x, point.y, point.z))
        .collect::<Vec<_>>();
    let (feature_vertices, feature_faces) =
        parry3d_f64::transformation::try_convex_hull(&source_points).map_err(|_| {
            EnvelopeError::InvalidInput("rounded polyhedron vertices must span a 3D convex hull")
        })?;
    let feature_vertices = feature_vertices
        .into_iter()
        .map(|point| larnt::Vector::new(point.x, point.y, point.z))
        .collect::<Vec<_>>();
    let centroid = feature_vertices
        .iter()
        .copied()
        .fold(larnt::Vector::default(), |sum, point| sum.add(point))
        .mul_scalar(1.0 / feature_vertices.len() as f64);
    let face_normals = feature_faces
        .iter()
        .map(|face| {
            let [a, b, c] = face.map(|index| feature_vertices[index as usize]);
            let center = a.add(b).add(c).mul_scalar(1.0 / 3.0);
            let mut normal = b.sub(a).cross(c.sub(a)).normalize();
            if normal.dot(center.sub(centroid)) < 0.0 {
                normal = normal.mul_scalar(-1.0);
            }
            normal
        })
        .collect::<Vec<_>>();
    let mut edge_faces = std::collections::HashMap::<(usize, usize), Vec<usize>>::new();
    for (face_index, face) in feature_faces.iter().enumerate() {
        for edge in [(face[0], face[1]), (face[1], face[2]), (face[2], face[0])] {
            let edge = (edge.0 as usize, edge.1 as usize);
            let key = if edge.0 < edge.1 {
                edge
            } else {
                (edge.1, edge.0)
            };
            edge_faces.entry(key).or_default().push(face_index);
        }
    }
    let mut edge_bands = Vec::new();
    for ((start, end), faces) in edge_faces {
        if faces.len() != 2 || face_normals[faces[0]].dot(face_normals[faces[1]]) > 0.995 {
            continue;
        }
        for blend in [0.2, 0.5, 0.8] {
            let radial = face_normals[faces[0]]
                .mul_scalar(1.0 - blend)
                .add(face_normals[faces[1]].mul_scalar(blend))
                .normalize()
                .mul_scalar(radius * 1.004);
            edge_bands.push(vec![
                feature_vertices[start].add(radial),
                feature_vertices[end].add(radial),
            ]);
        }
    }

    let golden_angle = std::f64::consts::PI * (3.0 - 5.0_f64.sqrt());
    let support_points = vertices
        .iter()
        .flat_map(|vertex| {
            (0..detail).map(move |index| {
                let z = 1.0 - 2.0 * (index as f64 + 0.5) / detail as f64;
                let radial = (1.0 - z * z).sqrt();
                let angle = golden_angle * index as f64;
                parry3d_f64::math::Vector::new(
                    vertex.x + radius * radial * angle.cos(),
                    vertex.y + radius * radial * angle.sin(),
                    vertex.z + radius * z,
                )
            })
        })
        .collect::<Vec<_>>();
    let (hull_vertices, hull_faces) = parry3d_f64::transformation::try_convex_hull(&support_points)
        .map_err(|_| {
            EnvelopeError::InvalidInput("rounded polyhedron vertices must span a 3D convex hull")
        })?;
    let mesh_vertices = hull_vertices
        .into_iter()
        .map(|point| larnt::Vector::new(point.x, point.y, point.z))
        .collect();
    let triangles = hull_faces
        .into_iter()
        .flatten()
        .map(|index| index as usize)
        .collect();
    let mut mesh = larnt::Mesh::builder(mesh_vertices, triangles).build();
    mesh.texture = match pattern {
        LinePattern::Outline => larnt::MeshTexture::Silhouette(0.0),
        LinePattern::Striped(_) => larnt::MeshTexture::Polygonal,
        LinePattern::LitHatch { .. } => unreachable!(),
    };
    Ok(RoundedPolyhedronSurface {
        mesh,
        edge_bands,
        pattern,
    })
}

fn shape_to_larnt(shape: LarntShape) -> Result<larnt::Primitive, EnvelopeError> {
    Ok(match shape {
        LarntShape::Sphere {
            center,
            radius,
            pattern,
        } => {
            let texture = match pattern {
                SpherePattern::Outline => larnt::SphereTexture::Outline,
                SpherePattern::LatLng {
                    latitudes,
                    longitudes,
                } if latitudes > 0 && longitudes > 0 => larnt::SphereTexture::LatLng {
                    n: latitudes,
                    o: longitudes,
                },
                SpherePattern::RandomEquators { seed, count } if count > 0 => {
                    larnt::SphereTexture::RandomEquators { seed, n: count }
                }
                SpherePattern::RandomCircles { seed, count } if count > 0 => {
                    larnt::SphereTexture::RandomCircles { seed, num: count }
                }
                SpherePattern::LitHatch {
                    light,
                    count,
                    length,
                    crosshatch,
                    seed,
                } if count > 0
                    && length > 0.0
                    && (0.0..=1.0).contains(&crosshatch)
                    && vector(light).length_squared() > 0.0 =>
                {
                    let sphere = larnt::Sphere::builder(vector(center), radius).build();
                    return Ok(larnt::Primitive::Dynamic(Box::new(LitSphere {
                        sphere,
                        light: vector(light),
                        count,
                        length,
                        crosshatch,
                        seed,
                    })));
                }
                SpherePattern::LitStipple {
                    light,
                    count,
                    min_size,
                    max_size,
                    gamma,
                    distribution,
                    seed,
                } if count > 0
                    && min_size > 0.0
                    && max_size >= min_size
                    && gamma > 0.0
                    && vector(light).length_squared() > 0.0 =>
                {
                    let sphere = larnt::Sphere::builder(vector(center), radius).build();
                    return Ok(larnt::Primitive::Dynamic(Box::new(StippledSphere {
                        sphere,
                        light: vector(light),
                        count,
                        min_size,
                        max_size,
                        gamma,
                        distribution,
                        seed,
                    })));
                }
                _ => {
                    return Err(EnvelopeError::InvalidInput(
                        "sphere pattern counts must be positive",
                    ));
                }
            };
            larnt::Sphere::builder(vector(center), radius)
                .texture(texture)
                .build()
                .into()
        }
        LarntShape::Cube { min, max, pattern } => {
            let texture = match line_count(pattern)? {
                None => larnt::CubeTexture::Vanilla,
                Some(count) => larnt::CubeTexture::Striped(count),
            };
            larnt::Cube::builder(vector(min), vector(max))
                .texture(texture)
                .build()
                .into()
        }
        LarntShape::Cylinder {
            radius,
            start,
            end,
            pattern,
        } => {
            if let LinePattern::LitHatch {
                light,
                count,
                length,
                crosshatch,
                seed,
            } = pattern
            {
                let base: larnt::Primitive =
                    larnt::new_transformed_cylinder(vector(start), vector(end), radius)
                        .texture(larnt::CylinderTexture::Outline)
                        .call()
                        .into();
                return Ok(larnt::Primitive::Dynamic(Box::new(LitAxialSurface {
                    base,
                    start: vector(start),
                    end: vector(end),
                    radius,
                    cone: false,
                    hatch: hatch_settings(light, count, length, crosshatch, seed)?,
                })));
            }
            let texture = match line_count(pattern)? {
                None => larnt::CylinderTexture::Outline,
                Some(count) => larnt::CylinderTexture::Striped(count),
            };
            larnt::new_transformed_cylinder(vector(start), vector(end), radius)
                .texture(texture)
                .call()
                .into()
        }
        LarntShape::Cone {
            radius,
            base,
            apex,
            pattern,
        } => {
            if let LinePattern::LitHatch {
                light,
                count,
                length,
                crosshatch,
                seed,
            } = pattern
            {
                let base_shape: larnt::Primitive =
                    larnt::new_transformed_cone(vector(base), vector(apex), radius)
                        .texture(larnt::ConeTexture::Outline)
                        .call()
                        .into();
                return Ok(larnt::Primitive::Dynamic(Box::new(LitAxialSurface {
                    base: base_shape,
                    start: vector(base),
                    end: vector(apex),
                    radius,
                    cone: true,
                    hatch: hatch_settings(light, count, length, crosshatch, seed)?,
                })));
            }
            let texture = match line_count(pattern)? {
                None => larnt::ConeTexture::Outline,
                Some(count) => larnt::ConeTexture::Striped(count),
            };
            larnt::new_transformed_cone(vector(base), vector(apex), radius)
                .texture(texture)
                .call()
                .into()
        }
        LarntShape::Torus {
            center,
            major_radius,
            minor_radius,
            pattern,
        } => {
            if major_radius <= 0.0 || minor_radius <= 0.0 || minor_radius >= major_radius {
                return Err(EnvelopeError::InvalidInput(
                    "torus radii must be positive and minor radius smaller than major radius",
                ));
            }
            match pattern {
                LinePattern::LitHatch {
                    light,
                    count,
                    length,
                    crosshatch,
                    seed,
                } => {
                    let mut mesh =
                        torus_surface(vector(center), major_radius, minor_radius, 72, 36)
                            .into_mesh();
                    mesh.texture = larnt::MeshTexture::Silhouette(0.0);
                    larnt::Primitive::Dynamic(Box::new(LitTorus {
                        mesh,
                        center: vector(center),
                        major_radius,
                        minor_radius,
                        hatch: hatch_settings(light, count, length, crosshatch, seed)?,
                    }))
                }
                LinePattern::Outline => {
                    let mut mesh =
                        torus_surface(vector(center), major_radius, minor_radius, 72, 36)
                            .into_mesh();
                    mesh.texture = larnt::MeshTexture::Silhouette(0.0);
                    mesh.into()
                }
                LinePattern::Striped(count) if count > 2 && count <= 180 => torus_surface(
                    vector(center),
                    major_radius,
                    minor_radius,
                    count as usize,
                    (count as usize / 2).max(3),
                )
                .into(),
                LinePattern::Striped(_) => {
                    return Err(EnvelopeError::InvalidInput(
                        "torus stripe count must be between 3 and 180",
                    ));
                }
            }
        }
        LarntShape::Tube {
            points,
            radius,
            sides,
            closed,
            pattern,
        } => larnt::Primitive::Dynamic(Box::new(build_tube_surface(
            points.into_iter().map(vector).collect(),
            radius,
            sides,
            closed,
            pattern,
        )?)),
        LarntShape::Ellipsoid {
            center,
            radii,
            pattern,
        } => {
            if radii
                .iter()
                .any(|radius| !radius.is_finite() || *radius <= 0.0)
            {
                return Err(EnvelopeError::InvalidInput(
                    "ellipsoid radii must be finite and positive",
                ));
            }
            let sphere = shape_to_larnt(LarntShape::Sphere {
                center: [0.0, 0.0, 0.0],
                radius: 1.0,
                pattern,
            })?;
            let transform = larnt::Matrix::identity()
                .scaled(vector(radii))
                .translated(vector(center));
            larnt::TransformedShape::new(sphere, transform).into()
        }
        LarntShape::RoundedPolyhedron {
            vertices,
            radius,
            detail,
            pattern,
        } => larnt::Primitive::Dynamic(Box::new(rounded_polyhedron_surface(
            vertices.into_iter().map(vector).collect(),
            radius,
            detail,
            pattern,
        )?)),
    })
}

fn validate_scene(scene: &LarntScene) -> Result<(), EnvelopeError> {
    let camera_values = scene
        .eye
        .iter()
        .chain(scene.center.iter())
        .chain(scene.up.iter());
    if !camera_values
        .chain([
            &scene.width,
            &scene.height,
            &scene.fovy,
            &scene.near,
            &scene.far,
            &scene.step,
        ])
        .all(|value| value.is_finite())
    {
        return Err(EnvelopeError::InvalidInput("scene values must be finite"));
    }
    if scene.shapes.is_empty()
        || scene.width <= 0.0
        || scene.height <= 0.0
        || scene.near <= 0.0
        || scene.far <= scene.near
        || scene.step < 0.0
    {
        return Err(EnvelopeError::InvalidInput("invalid scene dimensions"));
    }
    Ok(())
}

#[cfg(all(feature = "typst-plugin", target_arch = "wasm32"))]
mod typst_plugin {
    use wasm_minimal_protocol::*;

    initiate_protocol!();

    #[wasm_func]
    pub fn envelope_stroke(input: &[u8]) -> Vec<u8> {
        super::envelope_stroke(input)
    }

    #[wasm_func]
    pub fn larnt_paths(input: &[u8]) -> Vec<u8> {
        super::larnt_paths(input)
    }
}

#[cfg(test)]
mod larnt_tests {
    use super::*;

    #[test]
    fn lit_hatching_is_deterministic_and_adds_visible_paths() {
        let scene = LarntScene {
            shapes: vec![LarntShape::Sphere {
                center: [0.0, 0.0, 0.0],
                radius: 1.0,
                pattern: SpherePattern::LitHatch {
                    light: [-1.0, -0.5, 1.0],
                    count: 320,
                    length: 0.18,
                    crosshatch: 0.7,
                    seed: 42,
                },
            }],
            eye: [4.0, 5.0, 3.0],
            center: [0.0, 0.0, 0.0],
            up: [0.0, 0.0, 1.0],
            width: 8.0,
            height: 8.0,
            fovy: 40.0,
            near: 0.1,
            far: 100.0,
            step: 0.02,
        };
        let request = bincode::serialize(&scene).unwrap();
        let first = try_larnt_paths(&request).unwrap();
        let second = try_larnt_paths(&request).unwrap();
        let paths: ProjectedPaths = bincode::deserialize(&first).unwrap();

        assert_eq!(first, second);
        assert!(paths.len() > 8);
        assert!(paths.iter().all(|path| path.len() >= 2));
    }

    #[test]
    fn lit_stippling_is_dense_and_deterministic() {
        let scene = LarntScene {
            shapes: vec![LarntShape::Sphere {
                center: [0.0, 0.0, 0.0],
                radius: 1.0,
                pattern: SpherePattern::LitStipple {
                    light: [-1.0, -0.5, 1.0],
                    count: 4_000,
                    min_size: 0.006,
                    max_size: 0.035,
                    gamma: 1.35,
                    distribution: PointDistribution::Random,
                    seed: 73,
                },
            }],
            eye: [4.0, 5.0, 3.0],
            center: [0.0, 0.0, 0.0],
            up: [0.0, 0.0, 1.0],
            width: 8.0,
            height: 8.0,
            fovy: 40.0,
            near: 0.1,
            far: 100.0,
            step: 0.02,
        };
        let request = bincode::serialize(&scene).unwrap();
        let first = try_larnt_paths(&request).unwrap();
        let second = try_larnt_paths(&request).unwrap();
        let paths: ProjectedPaths = bincode::deserialize(&first).unwrap();
        let mut fibonacci_scene = scene;
        let LarntShape::Sphere { pattern, .. } = &mut fibonacci_scene.shapes[0] else {
            unreachable!();
        };
        let SpherePattern::LitStipple { distribution, .. } = pattern else {
            unreachable!();
        };
        *distribution = PointDistribution::Fibonacci;
        let fibonacci = try_larnt_paths(&bincode::serialize(&fibonacci_scene).unwrap()).unwrap();

        assert_eq!(first, second);
        assert_ne!(first, fibonacci);
        assert!(paths.len() > 300);
    }

    #[test]
    fn lit_axial_and_torus_surfaces_project_hatch_paths() {
        let hatch = LinePattern::LitHatch {
            light: [-1.0, -0.5, 1.0],
            count: 420,
            length: 0.2,
            crosshatch: 0.76,
            seed: 19,
        };
        let scene = LarntScene {
            shapes: vec![
                LarntShape::Cylinder {
                    radius: 0.5,
                    start: [-1.5, 0.0, -1.0],
                    end: [-1.5, 0.0, 1.0],
                    pattern: hatch,
                },
                LarntShape::Cone {
                    radius: 0.7,
                    base: [0.0, 0.0, -1.0],
                    apex: [0.0, 0.0, 1.0],
                    pattern: hatch,
                },
                LarntShape::Torus {
                    center: [1.6, 0.0, 0.0],
                    major_radius: 0.7,
                    minor_radius: 0.25,
                    pattern: hatch,
                },
            ],
            eye: [4.0, 6.0, 3.0],
            center: [0.0, 0.0, 0.0],
            up: [0.0, 0.0, 1.0],
            width: 10.0,
            height: 6.0,
            fovy: 42.0,
            near: 0.1,
            far: 100.0,
            step: 0.02,
        };
        let output = try_larnt_paths(&bincode::serialize(&scene).unwrap()).unwrap();
        let paths: ProjectedPaths = bincode::deserialize(&output).unwrap();

        assert!(paths.len() > 30);
        assert!(
            paths
                .iter()
                .flatten()
                .flatten()
                .all(|value| value.is_finite())
        );
    }

    #[test]
    fn generic_closed_tube_projects_a_trefoil() {
        let samples = 96;
        let points = (0..samples)
            .map(|index| {
                let t = std::f64::consts::TAU * index as f64 / samples as f64;
                [
                    (2.0 + (3.0 * t).cos()) * (2.0 * t).cos(),
                    (2.0 + (3.0 * t).cos()) * (2.0 * t).sin(),
                    (3.0 * t).sin(),
                ]
            })
            .collect();
        let scene = LarntScene {
            shapes: vec![LarntShape::Tube {
                points,
                radius: 0.18,
                sides: 12,
                closed: true,
                pattern: LinePattern::Striped(32),
            }],
            eye: [7.0, 9.0, 6.0],
            center: [0.0, 0.0, 0.0],
            up: [0.0, 0.0, 1.0],
            width: 11.0,
            height: 8.0,
            fovy: 38.0,
            near: 0.1,
            far: 100.0,
            step: 0.02,
        };
        let request = bincode::serialize(&scene).unwrap();
        let first = try_larnt_paths(&request).unwrap();
        let second = try_larnt_paths(&request).unwrap();
        let paths: ProjectedPaths = bincode::deserialize(&first).unwrap();

        assert_eq!(first, second);
        assert!(paths.len() > 20);
    }

    #[test]
    fn ellipsoid_and_rounded_polyhedron_project() {
        let scene = LarntScene {
            shapes: vec![
                LarntShape::Ellipsoid {
                    center: [-1.5, 0.0, 0.0],
                    radii: [1.1, 0.65, 0.8],
                    pattern: SpherePattern::LitHatch {
                        light: [1.0, -0.4, 1.0],
                        count: 420,
                        length: 0.2,
                        crosshatch: 0.78,
                        seed: 29,
                    },
                },
                LarntShape::RoundedPolyhedron {
                    vertices: vec![
                        [0.5, -0.7, -0.7],
                        [2.1, -0.7, -0.7],
                        [1.3, 0.9, -0.7],
                        [1.3, 0.0, 0.9],
                    ],
                    radius: 0.18,
                    detail: 32,
                    pattern: LinePattern::Outline,
                },
            ],
            eye: [5.0, 7.0, 4.0],
            center: [0.0, 0.0, 0.0],
            up: [0.0, 0.0, 1.0],
            width: 8.0,
            height: 5.0,
            fovy: 38.0,
            near: 0.1,
            far: 100.0,
            step: 0.02,
        };
        let output = try_larnt_paths(&bincode::serialize(&scene).unwrap()).unwrap();
        let paths: ProjectedPaths = bincode::deserialize(&output).unwrap();

        assert!(paths.len() > 10);
        assert!(
            paths
                .iter()
                .flatten()
                .flatten()
                .all(|value| value.is_finite())
        );
    }
}
