#import "geometry.typ" as geometry

#let rod(start, end, radius: 0.06, pattern: (geometry.texture.outline)()) = {
  geometry.cylinder(radius, start, end, pattern: pattern)
}

#let collar(start, end, radius: 0.2, stripes: 14) = {
  geometry.cylinder(radius, start, end, pattern: (geometry.texture.striped)(stripes))
}

#let joint(center, radius: 0.2, pattern: (geometry.texture.outline)()) = {
  geometry.sphere(center, radius, pattern: pattern)
}

#let lit-joint(
  center,
  radius: 0.2,
  light: (-1.0, -0.5, 1.0),
  count: 360,
  crosshatch: 0.72,
  seed: 0,
) = geometry.sphere(
  center,
  radius,
  pattern: (geometry.texture.lit-hatch)(
    light: light,
    count: count,
    length: 0.18,
    crosshatch: crosshatch,
    seed: seed,
  ),
)
