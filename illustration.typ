#import "@preview/cetz:0.4.2"
#import "nib-stroke.typ" as stroke

#let palette = (
  paper: rgb("f3ead9"),
  ink: rgb("272119"),
  pale-ink: rgb("786a58"),
)

#let canvas(body, length: 1cm) = cetz.canvas(length: length, body)

#let line-path(start, end) = {
  let (x0, y0) = start
  let (x1, y1) = end
  (((x0, y0),
    (x0 + (x1 - x0) / 3, y0 + (y1 - y0) / 3),
    (x0 + 2 * (x1 - x0) / 3, y0 + 2 * (y1 - y0) / 3),
    (x1, y1)),)
}

#let engraved(
  path,
  width: 0.018,
  angle: 24deg,
  dash: none,
  pressure: none,
  epsilon: 0.004,
  ink: palette.ink,
) = stroke.nib-stroke(
  path,
  pen: (width * 1.7, width * 0.55, angle),
  dash: dash,
  pressure: pressure,
  epsilon: epsilon,
  fill: ink,
)

#let _point-transform(point, origin: (0, 0), size: 1.0, direction: 0deg, mirror: false) = {
  let (x, y) = point
  let (ox, oy) = origin
  let xx = if mirror { -x } else { x }
  let c = calc.cos(direction)
  let s = calc.sin(direction)
  (ox + size * (xx * c - y * s), oy + size * (xx * s + y * c))
}

#let _path-transform(path, origin: (0, 0), size: 1.0, direction: 0deg, mirror: false) = path.map(
  segment => segment.map(
    point => _point-transform(point, origin: origin, size: size, direction: direction, mirror: mirror),
  ),
)

#let _ellipse-points(center, radii, samples: 32) = range(samples).map(index => {
  let angle = index / samples * 2 * calc.pi
  (center.at(0) + radii.at(0) * calc.cos(angle), center.at(1) + radii.at(1) * calc.sin(angle))
})

#let _svg-placeholder(path, origin, direction, size, mirror: false) = {
  let body = image(path, width: size * 1cm)
  if mirror {
    body = scale(x: -100%, body)
  }
  cetz.draw.content(origin, body, angle: direction, padding: 0pt)
}

#let _profile-eye(origin, direction, size, mirror) = {
  let transform-point(point) = _point-transform(
    point,
    origin: origin,
    size: size,
    direction: direction,
    mirror: mirror,
  )
  let transform-path(path) = _path-transform(
    path,
    origin: origin,
    size: size,
    direction: direction,
    mirror: mirror,
  )
  let globe = (
    ((0.62, 0.0), (0.52, 0.58), (0.12, 0.82), (-0.38, 0.64)),
    ((-0.38, 0.64), (-0.72, 0.49), (-0.83, 0.20), (-0.86, 0.0)),
    ((-0.86, 0.0), (-0.83, -0.20), (-0.72, -0.49), (-0.38, -0.64)),
    ((-0.38, -0.64), (0.12, -0.82), (0.52, -0.58), (0.62, 0.0)),
  )
  let cornea = (
    ((0.62, 0.0), (0.70, 0.30), (0.83, 0.34), (0.92, 0.0)),
    ((0.92, 0.0), (0.83, -0.34), (0.70, -0.30), (0.62, 0.0)),
  )
  let lens = (
    ((0.42, 0.0), (0.30, 0.27), (0.16, 0.27), (0.07, 0.0)),
    ((0.07, 0.0), (0.16, -0.27), (0.30, -0.27), (0.42, 0.0)),
  )
  let optic-nerve = (
    ((-0.77, 0.13), (-0.94, 0.16), (-1.09, 0.13), (-1.24, 0.09)),
    ((-0.77, -0.13), (-0.94, -0.16), (-1.09, -0.13), (-1.24, -0.09)),
  )

  cetz.draw.line(
    .._ellipse-points((-0.08, 0), (0.60, 0.57), samples: 48).map(transform-point),
    close: true,
    stroke: none,
    fill: palette.paper,
  )
  cetz.draw.line(
    .._ellipse-points((0.26, 0), (0.13, 0.24), samples: 32).map(transform-point),
    close: true,
    stroke: none,
    fill: palette.pale-ink,
  )

  stroke.nib-stroke(
    transform-path(globe),
    closed: true,
    pen: (0.030 * size, 0.008 * size, direction + 22deg),
    epsilon: 0.003,
    fill: palette.ink,
  )
  stroke.nib-stroke(
    transform-path(cornea),
    closed: true,
    pen: (0.024 * size, 0.006 * size, direction - 18deg),
    epsilon: 0.003,
    fill: palette.ink,
  )
  stroke.nib-stroke(
    transform-path(lens),
    closed: true,
    pen: (0.022 * size, 0.006 * size, direction + 28deg),
    epsilon: 0.003,
    fill: palette.ink,
  )
  for iris-leaf in (
    ((0.47, 0.36), (0.42, 0.22), (0.43, 0.10), (0.46, 0.035)),
    ((0.47, -0.36), (0.42, -0.22), (0.43, -0.10), (0.46, -0.035)),
  ) {
    stroke.nib-stroke(
      transform-path((iris-leaf,)),
      pen: (0.034 * size, 0.009 * size, direction - 12deg),
      epsilon: 0.003,
      fill: palette.ink,
    )
  }
  for nerve-edge in optic-nerve {
    stroke.nib-stroke(
      transform-path((nerve-edge,)),
      pen: (0.035 * size, 0.010 * size, direction + 8deg),
      epsilon: 0.003,
      fill: palette.ink,
    )
  }

  for y in (-0.42, -0.25, -0.08, 0.09, 0.26, 0.43) {
    let half = 0.48 * calc.sqrt(1 - calc.pow(y / 0.58, 2))
    stroke.nib-stroke(
      transform-path((((-0.12 - half, y), (-0.08, y + 0.05), (0.13, y - 0.04), (0.24, y)),)),
      pen: (0.010 * size, 0.003 * size, direction + 24deg),
      epsilon: 0.004,
      fill: palette.pale-ink,
    )
  }

  stroke.nib-stroke(
    transform-path((((-0.86, 0.0), (-0.48, 0.03), (-0.05, 0.02), (0.43, 0.0)),)),
    pen: (0.009 * size, 0.003 * size, direction),
    dash: (lengths: (0.11 * size, 0.08 * size), jitter: 0.004 * size, seed: 31),
    epsilon: 0.004,
    fill: palette.pale-ink,
  )
}

#let eye(
  origin: (0, 0),
  direction: 0deg,
  size: 1.0,
  view: "front",
  side: "right",
) = {
  assert(size > 0, message: "eye size must be positive")
  assert(view in ("front", "profile"), message: "eye view must be front or profile")
  assert(side in ("right", "left"), message: "eye side must be right or left")
  if view == "profile" {
    _profile-eye(origin, direction, size, side == "left")
    return
  }
  let upper = (((-0.75, -0.02), (-0.40, 0.42), (0.25, 0.44), (0.68, 0.04)),)
  let lower = (((-0.75, -0.02), (-0.38, -0.31), (0.30, -0.32), (0.68, 0.04)),)
  let crease = (((-0.68, 0.08), (-0.28, 0.54), (0.30, 0.49), (0.61, 0.13)),)
  let iris-center = (0.10, 0.04)

  let transform-point(point) = _point-transform(point, origin: origin, size: size, direction: direction)
  let transform-path(path) = _path-transform(path, origin: origin, size: size, direction: direction)
  let iris = _ellipse-points(iris-center, (0.255, 0.285)).map(transform-point)
  let pupil = _ellipse-points(iris-center, (0.105, 0.145)).map(transform-point)
  let highlight = _ellipse-points((-0.005, 0.155), (0.050, 0.067), samples: 20).map(transform-point)

  cetz.draw.line(..iris, close: true, stroke: none, fill: palette.pale-ink)
  cetz.draw.line(..pupil, close: true, stroke: none, fill: palette.ink)
  cetz.draw.line(..highlight, close: true, stroke: none, fill: palette.paper)
  stroke.nib-stroke(
    transform-path((
      ((-0.155, 0.04), (-0.155, 0.25), (0.355, 0.25), (0.355, 0.04)),
      ((0.355, 0.04), (0.355, -0.17), (-0.155, -0.17), (-0.155, 0.04)),
    )),
    closed: true,
    pen: (0.016 * size, 0.006 * size, direction + 18deg),
    epsilon: 0.003,
    fill: palette.ink,
  )
  stroke.nib-stroke(
    transform-path(upper),
    pen: (
      mode: "explicit",
      samples: (
        (arclength: 0, a: 0.040 * size, b: 0.010 * size, angle: direction + 15deg),
        (arclength: 1.5 * size, a: 0.022 * size, b: 0.006 * size, angle: direction + 31deg),
      ),
    ),
    epsilon: 0.003,
    fill: palette.ink,
  )
  stroke.nib-stroke(
    transform-path(lower),
    pen: (0.023 * size, 0.006 * size, direction - 18deg),
    epsilon: 0.003,
    fill: palette.ink,
  )
  stroke.nib-stroke(
    transform-path(crease),
    pen: (0.014 * size, 0.004 * size, direction + 24deg),
    epsilon: 0.003,
    fill: palette.pale-ink,
  )

  let upper-lashes = (
    ((-0.56, 0.17), (-0.59, 0.31), (-0.63, 0.39), (-0.70, 0.46)),
    ((-0.36, 0.30), (-0.38, 0.43), (-0.39, 0.51), (-0.43, 0.59)),
    ((-0.14, 0.38), (-0.13, 0.50), (-0.12, 0.58), (-0.13, 0.65)),
    ((0.09, 0.39), (0.12, 0.51), (0.15, 0.58), (0.17, 0.64)),
    ((0.31, 0.34), (0.36, 0.45), (0.40, 0.51), (0.45, 0.56)),
    ((0.50, 0.23), (0.57, 0.32), (0.63, 0.37), (0.70, 0.40)),
  )
  for (index, points) in upper-lashes.enumerate() {
    stroke.nib-stroke(
      transform-path((points,)),
      pen: (0.018 * size, 0.0045 * size, direction + (8 + index * 5) * 1deg),
      epsilon: 0.003,
      fill: palette.ink,
    )
  }

  let lower-lashes = (
    ((-0.43, -0.20), (-0.46, -0.28), (-0.48, -0.33), (-0.50, -0.38)),
    ((-0.16, -0.28), (-0.17, -0.35), (-0.17, -0.40), (-0.17, -0.44)),
    ((0.14, -0.27), (0.16, -0.34), (0.18, -0.39), (0.20, -0.43)),
    ((0.41, -0.18), (0.45, -0.24), (0.49, -0.28), (0.53, -0.31)),
  )
  for (index, points) in lower-lashes.enumerate() {
    stroke.nib-stroke(
      transform-path((points,)),
      pen: (0.012 * size, 0.0035 * size, direction - (12 + index * 4) * 1deg),
      epsilon: 0.003,
      fill: palette.ink,
    )
  }
}

#let hand-anchors(
  pose: "point",
  origin: (0, 0),
  direction: 0deg,
  size: 1.0,
  handedness: "right",
) = {
  assert(pose in ("point", "right-hand-rule"), message: "hand pose must be point or right-hand-rule")
  assert(handedness in ("right", "left"), message: "handedness must be right or left")
  let mirror = handedness == "left"
  let local = if pose == "point" {
    (wrist: (-0.42, 0), palm: (-0.08, 0), finger: (0.50, 0), thumb: (0.08, -0.18))
  } else {
    (wrist: (0, -0.50), palm: (0, -0.08), finger: (0, 0.50), thumb: (0.42, 0.05))
  }
  local.map(point => _point-transform(point, origin: origin, size: size, direction: direction, mirror: mirror))
}

// Temporary CC BY 4.0 Twemoji placeholders. See assets/twemoji/ATTRIBUTION.md.
#let hand(
  pose: "point",
  origin: (0, 0),
  direction: 0deg,
  size: 1.0,
  handedness: "right",
) = {
  assert(pose in ("point", "right-hand-rule"), message: "hand pose must be point or right-hand-rule")
  assert(handedness in ("right", "left"), message: "handedness must be right or left")
  let path = if pose == "point" { "assets/twemoji/point-right.svg" } else { "assets/twemoji/raised-hand.svg" }
  _svg-placeholder(path, origin, direction, size, mirror: handedness == "left")
}

#let figure-caption(body) = align(center, text(size: 8.5pt, style: "italic", body))

#let label(point, body, paper: palette.paper, ink: palette.ink) = cetz.draw.content(
  point,
  text(size: 9pt, style: "italic", fill: ink, body),
  padding: 1pt,
  fill: paper,
)
