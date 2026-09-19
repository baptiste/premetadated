#import "../lib.typ" as premetadated

#let ln = premetadated.geometry
#let drawing = premetadated.illustration
#let ink = drawing.palette.ink

#show: premetadated.style.plate.with(
  number: [Plate VII],
  title: [The Phases of the Moon],
  subtitle: [shown by one sphere under eight directions of the solar light],
  margin: (x: 22mm, y: 20mm),
  title-gap: 10mm,
)

#let phases = (
  ([I], [New moon], (0.0, 1.0, 0.0)),
  ([II], [First crescent], (-0.72, 0.72, 0.0)),
  ([III], [First quarter], (-1.0, 0.0, 0.0)),
  ([IV], [Waxing gibbous], (-0.72, -0.72, 0.0)),
  ([V], [Full moon], (0.0, -1.0, 0.0)),
  ([VI], [Waning gibbous], (0.72, -0.72, 0.0)),
  ([VII], [Last quarter], (1.0, 0.0, 0.0)),
  ([VIII], [Last crescent], (0.72, 0.72, 0.0)),
)

#let phase-cell(number, name, light, seed) = [
  #align(center)[
    #drawing.canvas({
      ln.render(
        ln.sphere(
          (0.0, 0.0, 0.0),
          1.0,
          pattern: (ln.texture.lit-stipple)(
            light: light,
            count: 6200,
            min-size: 0.0035,
            max-size: 0.030,
            gamma: 0.95,
            distribution: "random",
            seed: seed,
          ),
        ),
        eye: (0.0, -5.0, 0.35),
        center: (0.0, 0.0, 0.0),
        up: (0.0, 0.0, 1.0),
        width: 4.0,
        height: 4.0,
        fovy: 31.0,
        step: 0.016,
        pen: (0.017, 0.0055, 20deg),
        epsilon: 0.003,
        fill: ink,
      )
    })
    #v(1mm)
    #text(size: 8pt, smallcaps[#number])
    #h(0.5em)
    #text(size: 9pt, style: "italic")[#name]
  ]
]

#grid(
  columns: (1fr, 1fr),
  gutter: 15mm,
  row-gutter: 9mm,
  ..phases.enumerate().map(((index, phase)) => phase-cell(..phase, index + 101)),
)

#v(10mm)

#align(center)[
  #block(width: 125mm)[
    The eye remains fixed while the illumination turns around the globe. The
    bright limb is left nearly clear; stippled marks gather sharply toward the
    terminator and dark hemisphere. Thus the phase is expressed by discrete
    paths upon the solid, rather than by a clipped black disc.
  ]
]