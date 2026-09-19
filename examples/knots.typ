#import "../lib.typ" as premetadated

#let geo = premetadated.geometry
#let drawing = premetadated.illustration
#let ink = drawing.palette.ink
#let tau = 2 * calc.pi

#show: premetadated.style.plate.with(
  number: [Plate VIII],
  title: [Knots and Tubular Curves],
  subtitle: [different solids swept from one general construction],
  margin: (x: 20mm, y: 18mm),
)

#let torus-knot(p, q, major: 1.55, minor: 0.62) = t => (
  (major + minor * calc.cos(q * t)) * calc.cos(p * t),
  (major + minor * calc.cos(q * t)) * calc.sin(p * t),
  minor * calc.sin(q * t),
)

#let helix(t) = (
  1.25 * calc.cos(3.5 * t),
  1.25 * calc.sin(3.5 * t),
  0.75 * t - 2.35,
)

#let hatch = (geo.texture.lit-hatch)(
  light: (1.0, -0.4, 1.2),
  count: 760,
  length: 0.22,
  crosshatch: 0.78,
  seed: 23,
)

#let specimen(shape, caption, eye: (6.5, 8.0, 5.2), height: 6.2) = [
  #align(center)[
    #drawing.canvas({
      geo.render(
        shape,
        eye: eye,
        center: (0.0, 0.0, 0.0),
        width: 8.5,
        height: height,
        fovy: 37.0,
        step: 0.016,
        pen: (0.024, 0.006, 25deg),
        epsilon: 0.003,
        fill: ink,
      )
    })
    #v(1mm)
    #drawing.figure-caption(caption)
  ]
]

#grid(
  columns: (1fr, 1fr),
  gutter: 10mm,
  specimen(
    geo.tube-curve(
      torus-knot(2, 3),
      start: 0.0,
      end: tau,
      samples: 120,
      sides: 14,
      radius: 0.16,
      closed: true,
      pattern: (geo.texture.striped)(34),
    ),
    [Fig. 1. Trefoil, the $(2,3)$ torus knot.],
  ),
  specimen(
    geo.tube-curve(
      torus-knot(2, 5),
      start: 0.0,
      end: tau,
      samples: 150,
      sides: 14,
      radius: 0.13,
      closed: true,
      pattern: hatch,
    ),
    [Fig. 2. Cinquefoil, with lighting-aware rings.],
  ),
)

#v(10mm)

#specimen(
  geo.tube-curve(
    helix,
    start: 0.0,
    end: tau,
    samples: 120,
    sides: 14,
    radius: 0.14,
    pattern: (geo.texture.striped)(40),
  ),
  [Fig. 3. An open helix, capped automatically at both ends.],
  eye: (6.4, 7.4, 4.3),
  height: 5.6,
)

#v(9mm)

#premetadated.style.notes(
  premetadated.style.note([Construction.], [
    Each solid is defined only by a function returning a three-dimensional point.
    The package samples that centerline, transports a local frame along it, and
    sweeps a circular section to form the occluding mesh.
  ]),
  premetadated.style.note([Variation.], [
    Change the function, interval, radius, sampling density, or texture without
    adding a new shape implementation. Closed paths become knots; open paths
    become pipes, cords, springs, or diagrammatic trajectories.
  ]),
)
