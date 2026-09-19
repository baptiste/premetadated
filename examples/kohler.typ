#import "@preview/cetz:0.4.2"
#import "../lib.typ" as premetadated

#let optics = premetadated.optics
#let drawing = premetadated.illustration
#let ink = drawing.palette.ink
#let pale-ink = drawing.palette.pale-ink

#let exported = json("../kohler.json")
#let scene = optics.import-ray-optics(exported, beam-rays: 11, angle-rays: 3)
#let bounds = scene.bounds

#let boundary = (
  optics.blocker(bounds.p1, (bounds.p2.at(0), bounds.p1.at(1))),
  optics.blocker((bounds.p2.at(0), bounds.p1.at(1)), bounds.p2),
  optics.blocker(bounds.p2, (bounds.p1.at(0), bounds.p2.at(1))),
  optics.blocker((bounds.p1.at(0), bounds.p2.at(1)), bounds.p1),
)
#let traces = optics.trace-scene(
  (rays: scene.rays, elements: scene.elements + boundary),
  max-distance: 1200,
  max-interactions: 8,
)

#let scene-center = (
  (bounds.p1.at(0) + bounds.p2.at(0)) / 2,
  (bounds.p1.at(1) + bounds.p2.at(1)) / 2,
)
#let scale-factor = 70
#let project(point) = (
  (point.at(0) - scene-center.at(0)) / scale-factor,
  (scene-center.at(1) - point.at(1)) / scale-factor,
)
#let projected-path(points) = optics.ray-path(points.map(project))
#let add(a, b) = (a.at(0) + b.at(0), a.at(1) + b.at(1))
#let subtract(a, b) = (a.at(0) - b.at(0), a.at(1) - b.at(1))
#let multiply(vector, factor) = (vector.at(0) * factor, vector.at(1) * factor)
#let vector-length(vector) = calc.sqrt(vector.at(0) * vector.at(0) + vector.at(1) * vector.at(1))

#show: premetadated.style.plate.with(
  number: [Plate IX],
  title: [Köhler Illumination],
  subtitle: [rays computed from a Ray Optics Simulation scene],
  margin: (top: 22mm, bottom: 22mm, left: 20mm, right: 20mm),
)

#let kohler-figure = drawing.canvas(length: 1.18cm, {
  import cetz.draw: line, content

  // Computed paths are lighter than the optical hardware they explain.
  for trace in traces {
    if trace.points.len() >= 2 {
      drawing.engraved(
        projected-path(trace.points),
        width: 0.0065,
        angle: 12deg,
        epsilon: 0.002,
        ink: pale-ink,
      )
    }
  }

  // Source extent from the exported Beam object.
  let source = exported.objs.find(object => object.type == "Beam")
  drawing.engraved(
    drawing.line-path(
      project((source.p1.x, source.p1.y)),
      project((source.p2.x, source.p2.y)),
    ),
    width: 0.030,
    angle: 0deg,
  )

  for element in scene.elements {
    if element.type == "ideal-lens" {
      let p1 = project(element.p1)
      let p2 = project(element.p2)
      let midpoint = multiply(add(p1, p2), 0.5)
      let axis = subtract(p1, p2)
      let height = vector-length(axis) / 2
      let tangent = multiply(axis, 1 / vector-length(axis))
      let normal = (-tangent.at(1), tangent.at(0))
      let bulge = height * 0.24
      let lens-point(point) = add(
        midpoint,
        add(multiply(normal, point.at(0)), multiply(tangent, point.at(1))),
      )

      // Fine diagonal cuts and a variable elliptical-nib contour match the
      // engraved glass vocabulary used by optics-plate.typ.
      for index in range(-9, 10) {
        let y = index * height / 10
        let half = bulge * (1 - calc.pow(calc.abs(y / height), 1.55))
        if half > 0.01 {
          line(
            lens-point((-half, y - 0.025)),
            lens-point((half, y + 0.025)),
            stroke: (paint: pale-ink, thickness: 0.22pt),
          )
        }
      }
      let outline = optics.lens-path(0, height, bulge).map(segment => segment.map(lens-point))
      premetadated.stroke.nib-stroke(
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
        fill: ink,
      )
      content(
        add(p1, multiply(tangent, 0.30)),
        text(size: 7.5pt, style: "italic")[f = #element.focal-length],
        padding: 1pt,
        fill: drawing.palette.paper,
      )
    } else if element.type == "aperture" {
      drawing.engraved(
        drawing.line-path(project(element.p1), project(element.opening-p1)),
        width: 0.035,
        angle: -16deg,
      )
      drawing.engraved(
        drawing.line-path(project(element.opening-p2), project(element.p2)),
        width: 0.035,
        angle: -16deg,
      )
    }
  }

  // Optical axis and compact component labels.
  let left = project((bounds.p1.at(0), scene-center.at(1)))
  let right = project((bounds.p2.at(0), scene-center.at(1)))
  drawing.engraved(
    drawing.line-path(left, right),
    width: 0.006,
    dash: (lengths: (0.13, 0.10), jitter: 0.004, seed: 9),
    ink: pale-ink,
  )
  drawing.label(project((58.5, 590)), [extended source])
  drawing.label(project((177, 300)), [field stop])
  drawing.label(project((611, 215)), [aperture stop])
})
#align(center, kohler-figure)

#v(7mm)
#drawing.figure-caption[
  Fig. 1. Thirty-three rays sampled from the exported finite beam. Each ray is
  intersected with the nearest element, clipped by each aperture, and redirected
  by the thin-lens equation; no ray segments are positioned by hand.
]

#v(10mm)

#premetadated.style.notes(
  premetadated.style.note([Construction.], [
    The scene is read directly from `kohler.json`. Pixel coordinates are retained
    for the optical calculation and transformed only when the finished traces are
    engraved on the plate.
  ]),
  premetadated.style.note([Interpretation.], [
    The first lens images the extended source toward the aperture stop. The
    second lens redirects the admitted pencil after the stop; blocked rays end at
    the opaque leaves rather than passing through them.
  ]),
)
