#import "@preview/cetz:0.4.2"

#let _plugin = plugin("elliptical_pen_envelope.wasm")

#let _u8(value) = bytes((value,))
#let _u32(value) = int(value).to-bytes(size: 4, endian: "little")
#let _u64(value) = int(value).to-bytes(size: 8, endian: "little")
#let _f64(value) = float(value).to-bytes(size: 8, endian: "little")
#let _angle(value) = if type(value) == angle { value / 1rad } else { value }

#let _point(point) = {
  assert.eq(point.len(), 2, message: "points must contain x and y")
  _f64(point.at(0)) + _f64(point.at(1))
}

#let _sample(sample) = {
  if type(sample) == dictionary {
    let output = _f64(sample.arclength)
    output += _f64(sample.a)
    output += _f64(sample.b)
    output += _f64(_angle(sample.at("angle", default: 0.0)))
    output
  } else {
    assert.eq(sample.len(), 4, message: "pen samples must be (arclength, a, b, angle)")
    _f64(sample.at(0)) + _f64(sample.at(1)) + _f64(sample.at(2)) + _f64(_angle(sample.at(3)))
  }
}

#let _samples(samples) = {
  let output = _u64(samples.len())
  for sample in samples {
    output += _sample(sample)
  }
  output
}

#let _encode-pen(pen) = {
  if type(pen) == dictionary {
    let samples = pen.samples
    if pen.at("mode", default: "explicit") == "calligraphic" {
      _u32(1) + _samples(samples) + _f64(_angle(pen.at("offset", default: 0.0)))
    } else {
      _u32(0) + _samples(samples)
    }
  } else {
    assert.eq(pen.len(), 3, message: "a constant pen must be (a, b, angle)")
    _u32(0) + _samples(((0.0, pen.at(0), pen.at(1), pen.at(2)),))
  }
}

#let _encode-dash(dash) = {
  if dash == none {
    return _u8(0)
  }
  let lengths = dash.at("lengths", default: dash.at("pattern", default: ()))
  let output = _u8(1) + _u64(lengths.len())
  for length in lengths {
    output += _f64(length)
  }
  output += _f64(dash.at("offset", default: 0.0))
  output += _f64(dash.at("jitter", default: 0.0))
  output += _u64(dash.at("seed", default: 0))
  output
}

#let _encode-pressure(pressure) = {
  if pressure == none {
    return _u8(0)
  }
  let output = _u8(1) + _f64(pressure.minimum-axis)
  output += _f64(pressure.period)
  output + _u64(pressure.at("seed", default: 0))
}

#let _encode(path, pen, closed, dash, pressure, epsilon) = {
  let output = _u64(path.len())
  for segment in path {
    assert.eq(segment.len(), 4, message: "cubic segments must contain P0, P1, P2, and P3")
    for point in segment {
      output += _point(point)
    }
  }
  output += _u8(if closed { 1 } else { 0 })
  output += _encode-pen(pen)
  output += _encode-dash(dash)
  output += _encode-pressure(pressure)
  output + _f64(epsilon)
}

#let _read-u64(data, cursor) = (
  int.from-bytes(data.slice(cursor, count: 8), endian: "little", signed: false),
  cursor + 8,
)

#let _read-f64(data, cursor) = (
  float.from-bytes(data.slice(cursor, count: 8), endian: "little"),
  cursor + 8,
)

#let _decode(data) = {
  let (polygon-count, cursor) = _read-u64(data, 0)
  let polygons = ()
  for _ in range(polygon-count) {
    let (point-count, next) = _read-u64(data, cursor)
    cursor = next
    let polygon = ()
    for _ in range(point-count) {
      let (x, next) = _read-f64(data, cursor)
      let (y, next-next) = _read-f64(data, next)
      cursor = next-next
      polygon.push((x, y))
    }
    polygons.push(polygon)
  }
  assert.eq(cursor, data.len(), message: "plugin returned trailing bytes")
  polygons
}

#let envelope(path, pen: none, closed: false, dash: none, pressure: none, epsilon: 0.01) = {
  assert(pen != none, message: "pen is required")
  _decode(_plugin.envelope_stroke(_encode(path, pen, closed, dash, pressure, epsilon)))
}

#let polyline-path(points) = {
  let segments = ()
  for pair in points.windows(2) {
    let p0 = pair.at(0)
    let p3 = pair.at(1)
    let delta = (p3.at(0) - p0.at(0), p3.at(1) - p0.at(1))
    segments.push((
      p0,
      (p0.at(0) + delta.at(0) / 3, p0.at(1) + delta.at(1) / 3),
      (p0.at(0) + 2 * delta.at(0) / 3, p0.at(1) + 2 * delta.at(1) / 3),
      p3,
    ))
  }
  segments
}

#let nib-stroke(
  path,
  pen: none,
  closed: false,
  dash: none,
  pressure: none,
  epsilon: 0.01,
  fill: black,
  stroke: none,
) = {
  assert(pen != none, message: "pen is required")
  let polygons = envelope(path, pen: pen, closed: closed, dash: dash, pressure: pressure, epsilon: epsilon)
  if polygons.len() == 0 {
    return ()
  }
  cetz.draw.compound-path({
    for polygon in polygons {
      cetz.draw.line(..polygon, close: true, stroke: none)
    }
  }, fill: fill, stroke: stroke, fill-rule: "non-zero")
}

#let nib-polylines(
  polylines,
  pen: none,
  dash: none,
  pressure: none,
  epsilon: 0.01,
  fill: black,
  stroke: none,
) = {
  assert(pen != none, message: "pen is required")
  for points in polylines {
    if points.len() >= 2 {
      nib-stroke(
        polyline-path(points),
        pen: pen,
        dash: dash,
        pressure: pressure,
        epsilon: epsilon,
        fill: fill,
        stroke: stroke,
      )
    }
  }
}