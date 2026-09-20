#import "nib-stroke.typ": nib-polylines

#let _plugin = plugin("elliptical_pen_envelope.wasm")

#let _u8(value) = bytes((value,))
#let _u32(value) = int(value).to-bytes(size: 4, endian: "little")
#let _u64(value) = int(value).to-bytes(size: 8, endian: "little")
#let _f64(value) = float(value).to-bytes(size: 8, endian: "little")

#let _vec3(point) = {
  assert.eq(point.len(), 3, message: "3D points must contain x, y, and z")
  _f64(point.at(0)) + _f64(point.at(1)) + _f64(point.at(2))
}

#let texture = (
  outline: () => (kind: "outline"),
  striped: count => (kind: "striped", count: count),
  lat-lng: (latitudes: 10, longitudes: 10) => (
    kind: "lat-lng",
    latitudes: latitudes,
    longitudes: longitudes,
  ),
  random-equators: (seed, count: 100) => (
    kind: "random-equators",
    seed: seed,
    count: count,
  ),
  random-circles: (seed, count: 140) => (
    kind: "random-circles",
    seed: seed,
    count: count,
  ),
  lit-hatch: (
    light: (-1.0, -0.5, 1.0),
    count: 500,
    length: 0.18,
    crosshatch: 0.72,
    seed: 0,
  ) => (
    kind: "lit-hatch",
    light: light,
    count: count,
    length: length,
    crosshatch: crosshatch,
    seed: seed,
  ),
  lit-stipple: (
    light: (-1.0, -0.5, 1.0),
    count: 4000,
    min-size: 0.006,
    max-size: 0.035,
    gamma: 1.35,
    distribution: "random",
    seed: 0,
  ) => (
    kind: "lit-stipple",
    light: light,
    count: count,
    min-size: min-size,
    max-size: max-size,
    gamma: gamma,
    distribution: distribution,
    seed: seed,
  ),
)

#let sphere(center, radius, pattern: (texture.outline)()) = (
  kind: "sphere",
  center: center,
  radius: radius,
  pattern: pattern,
)

#let cube(min, max, pattern: (texture.outline)()) = (
  kind: "cube",
  min: min,
  max: max,
  pattern: pattern,
)

#let cylinder(radius, start, end, pattern: (texture.outline)()) = (
  kind: "cylinder",
  radius: radius,
  start: start,
  end: end,
  pattern: pattern,
)

#let cone(radius, base, apex, pattern: (texture.outline)()) = (
  kind: "cone",
  radius: radius,
  base: base,
  apex: apex,
  pattern: pattern,
)

#let torus(center, major-radius, minor-radius, pattern: (texture.outline)()) = (
  kind: "torus",
  center: center,
  major-radius: major-radius,
  minor-radius: minor-radius,
  pattern: pattern,
)

#let tube(
  points,
  radius: 0.1,
  sides: 12,
  closed: false,
  cap: "flat",
  pattern: (texture.outline)(),
) = {
  let radii = if type(radius) == array {
    assert.eq(radius.len(), points.len(), message: "tube needs one radius per point")
    radius
  } else {
    (radius,) * points.len()
  }
  assert(cap in ("flat", "round", "none"), message: "tube cap must be flat, round, or none")
  (
    kind: "tube",
    points: points,
    radii: radii,
    sides: sides,
    closed: closed,
    cap: cap,
    pattern: pattern,
  )
}

#let tube-curve(
  curve,
  radius: 0.1,
  samples: 96,
  sides: 12,
  start: 0.0,
  end: 1.0,
  closed: false,
  cap: "flat",
  pattern: (texture.outline)(),
) = {
  assert(samples >= if closed { 3 } else { 1 }, message: "tube curve has too few samples")
  let intervals = if closed { samples } else { samples + 1 }
  let points = range(intervals).map(index => {
    let fraction = index / samples
    curve(start + (end - start) * fraction)
  })
  let radii = if type(radius) == function {
    range(intervals).map(index => {
      let fraction = index / samples
      radius(start + (end - start) * fraction)
    })
  } else {
    radius
  }
  tube(points, radius: radii, sides: sides, closed: closed, cap: cap, pattern: pattern)
}

#let ellipsoid(center, radii, pattern: (texture.outline)()) = (
  kind: "ellipsoid",
  center: center,
  radii: radii,
  pattern: pattern,
)

#let rounded-polyhedron(
  vertices,
  radius: 0.1,
  detail: 32,
  pattern: (texture.outline)(),
) = (
  kind: "rounded-polyhedron",
  vertices: vertices,
  radius: radius,
  detail: detail,
  pattern: pattern,
)

#let rounded-box(min, max, radius: 0.1, detail: 32, pattern: (texture.outline)()) = {
  let (x0, y0, z0) = min
  let (x1, y1, z1) = max
  rounded-polyhedron(
    (
      (x0, y0, z0), (x0, y0, z1), (x0, y1, z0), (x0, y1, z1),
      (x1, y0, z0), (x1, y0, z1), (x1, y1, z0), (x1, y1, z1),
    ),
    radius: radius,
    detail: detail,
    pattern: pattern,
  )
}

#let _line-pattern(pattern) = {
  if pattern.kind == "outline" {
    _u32(0)
  } else if pattern.kind == "striped" {
    _u32(1) + _u64(pattern.count)
  } else {
    assert.eq(pattern.kind, "lit-hatch", message: "expected outline, striped, or lit-hatch texture")
    let output = _u32(2) + _vec3(pattern.light) + _u64(pattern.count)
    output += _f64(pattern.length) + _f64(pattern.crosshatch) + _u64(pattern.seed)
    output
  }
}

#let _sphere-pattern(pattern) = {
  if pattern.kind == "outline" {
    _u32(0)
  } else if pattern.kind == "lat-lng" {
    _u32(1) + _u32(pattern.latitudes) + _u32(pattern.longitudes)
  } else if pattern.kind == "random-equators" {
    _u32(2) + _u64(pattern.seed) + _u64(pattern.count)
  } else if pattern.kind == "random-circles" {
    _u32(3) + _u64(pattern.seed) + _u64(pattern.count)
  } else if pattern.kind == "lit-hatch" {
    let output = _u32(4) + _vec3(pattern.light) + _u64(pattern.count)
    output += _f64(pattern.length) + _f64(pattern.crosshatch) + _u64(pattern.seed)
    output
  } else {
    assert.eq(pattern.kind, "lit-stipple", message: "unknown sphere texture")
    let output = _u32(5) + _vec3(pattern.light) + _u64(pattern.count)
    output += _f64(pattern.min-size) + _f64(pattern.max-size)
    assert(pattern.distribution in ("random", "fibonacci"), message: "stipple distribution must be random or fibonacci")
    output += _f64(pattern.gamma) + _u32(if pattern.distribution == "random" { 0 } else { 1 })
    output += _u64(pattern.seed)
    output
  }
}

#let _shape(shape) = {
  if shape.kind == "sphere" {
    _u32(0) + _vec3(shape.center) + _f64(shape.radius) + _sphere-pattern(shape.pattern)
  } else if shape.kind == "cube" {
    _u32(1) + _vec3(shape.min) + _vec3(shape.max) + _line-pattern(shape.pattern)
  } else if shape.kind == "cylinder" {
    _u32(2) + _f64(shape.radius) + _vec3(shape.start) + _vec3(shape.end) + _line-pattern(shape.pattern)
  } else if shape.kind == "cone" {
    _u32(3) + _f64(shape.radius) + _vec3(shape.base) + _vec3(shape.apex) + _line-pattern(shape.pattern)
  } else if shape.kind == "torus" {
    _u32(4) + _vec3(shape.center) + _f64(shape.major-radius) + _f64(shape.minor-radius) + _line-pattern(shape.pattern)
  } else if shape.kind == "tube" {
    let output = _u32(5) + _u64(shape.points.len())
    for point in shape.points {
      output += _vec3(point)
    }
    output += _u64(shape.radii.len())
    for radius in shape.radii {
      output += _f64(radius)
    }
    output += _u64(shape.sides) + _u8(if shape.closed { 1 } else { 0 })
    output += _u32(("flat", "round", "none").position(value => value == shape.cap))
    output + _line-pattern(shape.pattern)
  } else if shape.kind == "ellipsoid" {
    _u32(6) + _vec3(shape.center) + _vec3(shape.radii) + _sphere-pattern(shape.pattern)
  } else {
    assert.eq(shape.kind, "rounded-polyhedron", message: "unknown Larnt shape")
    let output = _u32(7) + _u64(shape.vertices.len())
    for vertex in shape.vertices {
      output += _vec3(vertex)
    }
    output += _f64(shape.radius) + _u64(shape.detail)
    output + _line-pattern(shape.pattern)
  }
}

#let _encode-scene(shapes, eye, center, up, width, height, fovy, near, far, step) = {
  let output = _u64(shapes.len())
  for shape in shapes {
    output += _shape(shape)
  }
  output += _vec3(eye) + _vec3(center) + _vec3(up)
  output += _f64(width) + _f64(height) + _f64(fovy)
  output += _f64(near) + _f64(far) + _f64(step)
  output
}

#let _read-u64(data, cursor) = (
  int.from-bytes(data.slice(cursor, count: 8), endian: "little", signed: false),
  cursor + 8,
)

#let _read-f64(data, cursor) = (
  float.from-bytes(data.slice(cursor, count: 8), endian: "little"),
  cursor + 8,
)

#let _decode-paths(data) = {
  let (path-count, cursor) = _read-u64(data, 0)
  let paths = ()
  for _ in range(path-count) {
    let (point-count, next) = _read-u64(data, cursor)
    cursor = next
    let points = ()
    for _ in range(point-count) {
      let (x, next) = _read-f64(data, cursor)
      let (y, next-next) = _read-f64(data, next)
      cursor = next-next
      points.push((x, y))
    }
    paths.push(points)
  }
  assert.eq(cursor, data.len(), message: "Larnt plugin returned trailing bytes")
  paths
}

#let paths(
  ..shapes,
  eye: (5.0, 5.0, 5.0),
  center: (0.0, 0.0, 0.0),
  up: (0.0, 0.0, 1.0),
  width: 10.0,
  height: 10.0,
  fovy: 50.0,
  near: 0.1,
  far: 1000.0,
  step: 0.02,
) = _decode-paths(_plugin.larnt_paths(_encode-scene(
  shapes.pos(), eye, center, up, width, height, fovy, near, far, step,
)))

#let render(
  ..shapes,
  pen: (0.035, 0.012, 25deg),
  pressure: none,
  eye: (5.0, 5.0, 5.0),
  center: (0.0, 0.0, 0.0),
  up: (0.0, 0.0, 1.0),
  width: 10.0,
  height: 10.0,
  fovy: 50.0,
  near: 0.1,
  far: 1000.0,
  step: 0.02,
  epsilon: 0.005,
  fill: black,
) = nib-polylines(
  paths(
    ..shapes,
    eye: eye,
    center: center,
    up: up,
    width: width,
    height: height,
    fovy: fovy,
    near: near,
    far: far,
    step: step,
  ),
  pen: pen,
  pressure: pressure,
  epsilon: epsilon,
  fill: fill,
)