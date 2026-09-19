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

#let _svg-placeholder(path, origin, direction, size, mirror: false) = {
  let body = image(path, width: size * 1cm)
  if mirror {
    body = scale(x: -100%, body)
  }
  cetz.draw.content(origin, body, angle: direction, padding: 0pt)
}

// Temporary CC BY 4.0 Twemoji placeholder. See assets/twemoji/ATTRIBUTION.md.
#let eye(origin: (0, 0), direction: 0deg, size: 1.0) = _svg-placeholder(
  "assets/twemoji/eye.svg",
  origin,
  direction,
  size,
)

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
