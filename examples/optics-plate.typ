#import "@preview/cetz:0.4.2"
#import "../lib.typ" as premetadated

#let ln = premetadated.geometry
#let drawing = premetadated.illustration
#let nib-stroke = premetadated.stroke.nib-stroke
#let line-path = drawing.line-path
#let engraved = drawing.engraved
#let lens-path = premetadated.optics.lens-path
#let label = drawing.label
#let paper = drawing.palette.paper
#let ink = drawing.palette.ink
#let pale-ink = drawing.palette.pale-ink

#show: premetadated.style.plate.with(
  number: [Plate IV],
  title: [The Compound Microscope],
  subtitle: [with the several pencils of light traced through the glasses],
  margin: (top: 22mm, bottom: 22mm, left: 25mm, right: 25mm),
  title-gap: 9mm,
)

#let lens(x, height, bulge, name) = {
  // Fine diagonal cuts read as engraved glass rather than a gray fill.
  for y in range(-10, 11) {
    let yy = y * height / 11
    let half = bulge * (1 - calc.pow(calc.abs(yy / height), 1.55))
    if half > 0.01 {
      cetz.draw.line(
        (x - half, yy - 0.075),
        (x + half, yy + 0.075),
        stroke: (paint: pale-ink, thickness: 0.22pt),
      )
    }
  }
  nib-stroke(
    lens-path(x, height, bulge),
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
  cetz.draw.content((x, height + 0.36), name, padding: 0pt)
}

#let microscope-perspective = drawing.canvas({
  ln.render(
    // Optical barrel, draw tube, objective, and eyepiece.
    ln.cylinder(0.62, (-1.85, 0.0, 2.12), (1.45, 0.0, 2.12), pattern: (ln.texture.striped)(18)),
    ln.cylinder(0.46, (1.45, 0.0, 2.12), (2.05, 0.0, 2.12), pattern: (ln.texture.outline)()),
    ln.cylinder(0.30, (2.05, 0.0, 2.12), (2.42, 0.0, 2.12), pattern: (ln.texture.striped)(12)),
    ln.cylinder(0.38, (-2.18, 0.0, 2.12), (-1.85, 0.0, 2.12), pattern: (ln.texture.outline)()),
    ln.cylinder(0.22, (-2.48, 0.0, 2.12), (-2.18, 0.0, 2.12), pattern: (ln.texture.striped)(12)),

    // Stage, pillar, foot, and focusing wheels.
    ln.cube((-2.40, -1.05, 0.82), (-0.72, 1.05, 0.96), pattern: (ln.texture.striped)(10)),
    ln.cylinder(0.18, (0.72, 0.0, 0.20), (0.72, 0.0, 1.72), pattern: (ln.texture.striped)(12)),
    ln.cylinder(0.16, (0.72, 0.0, 1.72), (0.10, 0.0, 2.03), pattern: (ln.texture.outline)()),
    ln.cube((-0.15, -0.82, 0.02), (1.82, 0.82, 0.22), pattern: (ln.texture.striped)(8)),
    ln.cylinder(0.34, (0.55, -0.34, 1.55), (0.55, 0.34, 1.55), pattern: (ln.texture.striped)(16)),
    ln.sphere((0.55, -0.47, 1.55), 0.21, pattern: (ln.texture.outline)()),
    ln.sphere((0.55, 0.47, 1.55), 0.21, pattern: (ln.texture.outline)()),

    eye: (5.6, 7.4, 4.7),
    center: (0.0, 0.0, 1.15),
    up: (0.0, 0.0, 1.0),
    width: 14.0,
    height: 5.4,
    fovy: 30.0,
    step: 0.018,
    pen: (0.030, 0.008, 27deg),
    epsilon: 0.004,
    fill: ink,
  )
})

#align(center)[#microscope-perspective]

#v(2mm)

#align(center)[
  #text(size: 8.5pt, style: "italic")[Fig. 1. General disposition of the tube, stage, pillar, and focusing wheel.]
]

#v(8mm)

#align(center)[
#drawing.canvas({
  import cetz.draw: *

  // Optical axis, printed as a lightly broken construction line.
  engraved(
    line-path((-5.8, 0), (6.1, 0)),
    width: 0.010,
    dash: (lengths: (0.18, 0.12), offset: 0, jitter: 0.008, seed: 17),
  )

  // Specimen and its small brass stage.
  engraved(line-path((-5.15, -0.72), (-5.15, 0.72)), width: 0.028, angle: -18deg)
  engraved(line-path((-5.42, -0.76), (-4.88, -0.76)), width: 0.022)
  engraved(line-path((-5.38, -0.86), (-4.92, -0.86)), width: 0.013)
  // A deliberately calligraphic specimen mark.
  nib-stroke(
    (((-5.15, -0.18), (-5.45, 0.18), (-4.87, 0.34), (-5.08, 0.62)),),
    pen: (
      mode: "calligraphic",
      offset: 32deg,
      samples: ((arclength: 0, a: 0.050, b: 0.013),),
    ),
    fill: ink,
  )

  // Objective and eyepiece groups in optical section.
  lens(-3.15, 1.12, 0.28, [A])
  lens(2.10, 1.36, 0.38, [B])
  lens(3.30, 1.05, 0.24, [C])

  // Tube shoulders, rendered as independent engraved contours.
  engraved(line-path((-2.82, 1.08), (1.68, 1.30)), width: 0.015)
  engraved(line-path((-2.82, -1.08), (1.68, -1.30)), width: 0.015)
  engraved(line-path((2.49, 1.27), (3.06, 1.02)), width: 0.014)
  engraved(line-path((2.49, -1.27), (3.06, -1.02)), width: 0.014)

  // Three computed-looking ray pencils. Their unequal elliptical nib makes
  // each direction carry a subtly different engraved weight.
  let rays = (
    ((-5.15, 0.56), (-3.15, 0.38), (0.45, -0.72), (2.10, -0.52), (3.30, -0.28), (5.55, 0.64)),
    ((-5.15, 0.18), (-3.15, 0.12), (0.45, -0.25), (2.10, -0.18), (3.30, -0.09), (5.55, 0.22)),
    ((-5.15, -0.34), (-3.15, -0.23), (0.45, 0.46), (2.10, 0.33), (3.30, 0.18), (5.55, -0.40)),
  )
  for ray in rays {
    for pair in ray.windows(2) {
      engraved(line-path(pair.first(), pair.last()), width: 0.009, angle: 12deg)
    }
  }

  // Virtual image plane and field stop.
  engraved(line-path((0.45, -0.83), (0.45, 0.58)), width: 0.012, angle: -30deg)
  engraved(line-path((0.31, -0.83), (0.59, -0.83)), width: 0.014)

  // Plain leaders and reference letters, kept as searchable text.
  line((-5.1, 0.72), (-5.65, 1.48), stroke: (paint: ink, thickness: 0.28pt))
  label((-5.78, 1.59), [Object])
  line((0.45, 0.58), (0.02, 1.48), stroke: (paint: ink, thickness: 0.28pt))
  label((-0.12, 1.60), [Inverted image])
  line((5.18, 0.49), (5.70, 1.25), stroke: (paint: ink, thickness: 0.28pt))
  label((5.74, 1.38), [To the eye])

  // A small printer's rule beneath the figure.
  engraved(line-path((-1.15, -2.05), (1.15, -2.05)), width: 0.012)
})
]

#v(7mm)

#align(center)[
  #text(size: 9pt, style: "italic")[Fig. 2. The objective A forms an inverted image; the glasses B and C enlarge its apparent angle.]
]

#v(1fr)

#grid(
  columns: (1fr, 1fr),
  gutter: 14mm,
  [
    #text(size: 9pt, smallcaps[Construction.])
    #h(0.35em)
    The upper instrument is projected from solid primitives with hidden lines
    removed before the visible paths receive an elliptical pen. The section
    below preserves the exact conjugate points and pencils of light.
  ],
  [
    #text(size: 9pt, smallcaps[Explanation.])
    #h(0.35em)
    Stripes follow the three-dimensional surfaces instead of imitating shaded
    pixels. Letters remain ordinary text, while line weight and direction carry
    the engraved character of the plate.
  ],
)

#v(12mm)

#align(right)[
  #text(size: 8pt, smallcaps[Drawn for the Optical Society])

  #v(4pt)
  #text(font: "IM FELL English", size: 14pt, style: "italic")[A. H. Mercer]
]