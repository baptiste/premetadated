#import "../lib.typ" as premetadated

#let ln = premetadated.geometry
#let nib = premetadated.stroke
#let drawing = premetadated.illustration
#let ink = drawing.palette.ink

#show: premetadated.style.plate.with(
  number: [Plate VI],
  title: [An Atlas of Line Shading],
  subtitle: [the density and crossing of strokes governed by illumination],
  margin: (x: 16mm, y: 13mm),
  title-gap: 6mm,
)

#let light = (1.0, -0.35, 1.0)
#let broad = (ln.texture.lit-hatch)(light: light, count: 420, length: 0.30, crosshatch: 1.0, seed: 11)
#let close = (ln.texture.lit-hatch)(light: light, count: 760, length: 0.22, crosshatch: 1.0, seed: 11)
#let crossed = (ln.texture.lit-hatch)(light: light, count: 980, length: 0.18, crosshatch: 0.76, seed: 11)

#let specimen(shape, pen: (0.022, 0.006, 24deg), pressure: none, outline: none) = [
  #align(center)[
    #drawing.canvas({
      ln.render(
        shape,
        eye: (4.2, 5.2, 3.0),
        width: 4.0,
        height: 3.25,
        fovy: 34.0,
        step: 0.018,
        pen: pen,
        pressure: pressure,
        epsilon: 0.003,
        fill: ink,
      )
      if outline != none {
        ln.render(
          outline,
          eye: (4.2, 5.2, 3.0),
          width: 4.0,
          height: 3.25,
          fovy: 34.0,
          step: 0.018,
          pen: (0.020, 0.006, 24deg),
          epsilon: 0.003,
          fill: ink,
        )
      }
    })
  ]
]

#let row(label, make-shape) = [
  #grid(
    columns: (16mm, 1fr, 1fr, 1fr),
    gutter: 3mm,
    align: center + horizon,
    rotate(-90deg, text(size: 8.5pt, tracking: 0.8pt, smallcaps[#label])),
    specimen(make-shape(broad), pen: (0.024, 0.010, 24deg)),
    specimen(
      make-shape(close),
      pen: (0.022, 0.0065, 24deg),
      pressure: (minimum-axis: 0.0075, period: 0.11, seed: 41),
      outline: make-shape((ln.texture.outline)()),
    ),
    specimen(
      make-shape(crossed),
      pen: (0.020, 0.005, 24deg),
      pressure: (minimum-axis: 0.0075, period: 0.10, seed: 59),
      outline: make-shape((ln.texture.outline)()),
    ),
  )
]

#grid(
  columns: (16mm, 1fr, 1fr, 1fr),
  gutter: 3mm,
  align: center,
  [],
  text(size: 8.5pt, style: "italic")[I. Broad contour],
  text(size: 8.5pt, style: "italic")[II. Broken close contour],
  text(size: 8.5pt, style: "italic")[III. Broken crossed shadow],
)

#v(2mm)
#row([Sphere], pattern => ln.sphere((0.0, 0.0, 0.0), 1.0, pattern: pattern))
#v(2mm)
#row([Cone], pattern => ln.cone(0.82, (0.0, 0.0, -1.0), (0.0, 0.0, 1.15), pattern: pattern))
#v(2mm)
#row([Cylinder], pattern => ln.cylinder(0.72, (0.0, 0.0, -1.05), (0.0, 0.0, 1.05), pattern: pattern))
#v(2mm)
#row([Torus], pattern => ln.torus((0.0, 0.0, 0.0), 0.78, 0.30, pattern: pattern))

#v(5mm)

#grid(
  columns: (1fr, 1fr),
  gutter: 7mm,
  align: center,
  [
    #specimen(
      ln.sphere((0.0, 0.0, 0.0), 1.0, pattern: (ln.texture.lit-stipple)(
        light: light, count: 5600, min-size: 0.004,
        max-size: 0.034, gamma: 1.05, distribution: "random", seed: 11,
      )),
      pen: (0.017, 0.006, 24deg),
    )
    #text(size: 8.5pt, style: "italic")[IV. Random graded stipple]
  ],
  [
    #specimen(
      ln.sphere((0.0, 0.0, 0.0), 1.0, pattern: (ln.texture.lit-stipple)(
        light: light, count: 5600, min-size: 0.004,
        max-size: 0.034, gamma: 1.05, distribution: "fibonacci", seed: 11,
      )),
      pen: (0.017, 0.006, 24deg),
    )
    #text(size: 8.5pt, style: "italic")[V. Fibonacci graded stipple]
  ],
)

#v(4mm)

#align(center)[
  #drawing.canvas({
    nib.nib-stroke(
      (((-6.0, 0.0), (-2.0, 0.5), (2.0, -0.5), (6.0, 0.0)),),
      pen: (
        mode: "explicit",
        samples: (
          (arclength: 0.0, a: 0.18, b: 0.085, angle: 18deg),
          (arclength: 6.0, a: 0.09, b: 0.035, angle: 18deg),
          (arclength: 12.1, a: 0.025, b: 0.008, angle: 18deg),
        ),
      ),
      pressure: (minimum-axis: 0.028, period: 0.32, seed: 17),
      epsilon: 0.003,
      fill: ink,
    )
  })
  #v(1mm)
  #text(size: 8.5pt, style: "italic")[VI. A tapered nib stroke, breaking below the printable width.]
]

#v(4mm)

#grid(
  columns: (1fr, 1fr),
  gutter: 12mm,
  [
    #text(size: 9pt, smallcaps[Construction.])
    #h(0.3em)
    Marks are laid on each solid before projection. Their extent increases as
    the surface normal turns from the light; hidden portions are removed by the geometry.
  ],
  [
    #text(size: 9pt, smallcaps[Observation.])
    #h(0.3em)
    No gray tone is painted. Apparent shade arises from the number, direction,
    and crossing of discrete engraved paths, all swept with the same elliptical nib.
  ],
)