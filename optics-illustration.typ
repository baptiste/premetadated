#import "@preview/cetz:0.4.2"
#import "optics.typ" as optics
#import "illustration.typ" as drawing
#import "nib-stroke.typ" as stroke

#let _add(a, b) = (a.at(0) + b.at(0), a.at(1) + b.at(1))
#let _sub(a, b) = (a.at(0) - b.at(0), a.at(1) - b.at(1))
#let _scale(vector, factor) = (vector.at(0) * factor, vector.at(1) * factor)
#let _length(vector) = calc.sqrt(vector.at(0) * vector.at(0) + vector.at(1) * vector.at(1))
#let _json-point(point) = (point.x, point.y)

#let import-scene(
  data,
  beam-rays: 13,
  angle-rays: 3,
  scale: 1,
  max-distance: 1000,
  max-interactions: 16,
) = {
  assert(scale > 0, message: "Optics illustration scale must be positive")
  let scene = optics.import-ray-optics(data, beam-rays: beam-rays, angle-rays: angle-rays)
  assert(scene.bounds != none, message: "An imported optics illustration needs a CropBox")
  let bounds = scene.bounds
  let boundary = (
    optics.blocker(bounds.p1, (bounds.p2.at(0), bounds.p1.at(1))),
    optics.blocker((bounds.p2.at(0), bounds.p1.at(1)), bounds.p2),
    optics.blocker(bounds.p2, (bounds.p1.at(0), bounds.p2.at(1))),
    optics.blocker((bounds.p1.at(0), bounds.p2.at(1)), bounds.p1),
  )
  let traces = optics.trace-scene(
    (rays: scene.rays, elements: scene.elements + boundary),
    max-distance: max-distance,
    max-interactions: max-interactions,
  )
  let center = (
    (bounds.p1.at(0) + bounds.p2.at(0)) / 2,
    (bounds.p1.at(1) + bounds.p2.at(1)) / 2,
  )
  (data: data, scene: scene, bounds: bounds, traces: traces, center: center, scale: scale)
}

#let project(diagram, point) = (
  (point.at(0) - diagram.center.at(0)) / diagram.scale,
  (diagram.center.at(1) - point.at(1)) / diagram.scale,
)

#let _draw-lens(diagram, element, show-focal-length: true) = {
  let p1 = project(diagram, element.p1)
  let p2 = project(diagram, element.p2)
  let midpoint = _scale(_add(p1, p2), 0.5)
  let axis = _sub(p1, p2)
  let height = _length(axis) / 2
  let tangent = _scale(axis, 1 / _length(axis))
  let normal = (-tangent.at(1), tangent.at(0))
  let bulge = height * 0.24
  let lens-point(point) = _add(
    midpoint,
    _add(_scale(normal, point.at(0)), _scale(tangent, point.at(1))),
  )

  for index in range(-9, 10) {
    let y = index * height / 10
    let half = bulge * (1 - calc.pow(calc.abs(y / height), 1.55))
    if half > 0.01 {
      cetz.draw.line(
        lens-point((-half, y - 0.025)),
        lens-point((half, y + 0.025)),
        stroke: (paint: drawing.palette.pale-ink, thickness: 0.22pt),
      )
    }
  }
  let outline = optics.lens-path(0, height, bulge).map(segment => segment.map(lens-point))
  stroke.nib-stroke(
    outline,
    closed: true,
    pen: (
      mode: "explicit",
      samples: (
        (arclength: 0, a: 0.026, b: 0.009, angle: 18deg),
        (arclength: 6, a: 0.018, b: 0.007, angle: 31deg),
      ),
    ),
    epsilon: 0.003,
    fill: drawing.palette.ink,
  )
  if show-focal-length {
    cetz.draw.content(
      _add(p1, _scale(tangent, 0.30)),
      text(size: 7.5pt, style: "italic")[f = #element.focal-length],
      padding: 1pt,
      fill: drawing.palette.paper,
    )
  }
}

#let _draw-mirror(diagram, element) = {
  let p1 = project(diagram, element.p1)
  let p2 = project(diagram, element.p2)
  let tangent = _scale(_sub(p2, p1), 1 / _length(_sub(p2, p1)))
  let backing-offset = _scale((-tangent.at(1), tangent.at(0)), 0.10)
  drawing.engraved(drawing.line-path(p1, p2), width: 0.026, angle: -12deg)
  drawing.engraved(
    drawing.line-path(_add(p1, backing-offset), _add(p2, backing-offset)),
    width: 0.009,
    angle: -12deg,
    dash: (lengths: (0.12, 0.08), jitter: 0.003, seed: 23),
    ink: drawing.palette.pale-ink,
  )
}

#let draw(
  diagram,
  show-axis: true,
  show-sources: true,
  show-focal-lengths: true,
) = {
  for trace in diagram.traces {
    if trace.points.len() >= 2 {
      drawing.engraved(
        optics.ray-path(trace.points.map(point => project(diagram, point))),
        width: 0.0065,
        angle: 12deg,
        epsilon: 0.002,
        ink: drawing.palette.pale-ink,
      )
    }
  }

  if show-sources {
    for source in diagram.data.objs.filter(object => object.type == "Beam") {
      drawing.engraved(
        drawing.line-path(project(diagram, _json-point(source.p1)), project(diagram, _json-point(source.p2))),
        width: 0.030,
        angle: 0deg,
      )
    }
  }

  for element in diagram.scene.elements {
    if element.type == "ideal-lens" {
      _draw-lens(diagram, element, show-focal-length: show-focal-lengths)
    } else if element.type == "mirror" {
      _draw-mirror(diagram, element)
    } else if element.type == "blocker" {
      drawing.engraved(
        drawing.line-path(project(diagram, element.p1), project(diagram, element.p2)),
        width: 0.045,
        angle: -16deg,
      )
    } else if element.type == "aperture" {
      drawing.engraved(
        drawing.line-path(project(diagram, element.p1), project(diagram, element.opening-p1)),
        width: 0.035,
        angle: -16deg,
      )
      drawing.engraved(
        drawing.line-path(project(diagram, element.opening-p2), project(diagram, element.p2)),
        width: 0.035,
        angle: -16deg,
      )
    } else if element.type == "beam-splitter" {
      drawing.engraved(
        drawing.line-path(project(diagram, element.p1), project(diagram, element.p2)),
        width: 0.016,
        angle: -12deg,
      )
    }
  }

  if show-axis {
    let left = project(diagram, (diagram.bounds.p1.at(0), diagram.center.at(1)))
    let right = project(diagram, (diagram.bounds.p2.at(0), diagram.center.at(1)))
    drawing.engraved(
      drawing.line-path(left, right),
      width: 0.006,
      dash: (lengths: (0.13, 0.10), jitter: 0.004, seed: 9),
      ink: drawing.palette.pale-ink,
    )
  }
}

#let label(diagram, point, body) = drawing.label(project(diagram, point), body)