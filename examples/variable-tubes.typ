#import "../lib.typ" as premetadated

#let geo = premetadated.geometry
#let drawing = premetadated.illustration
#let ink = drawing.palette.ink

#show: premetadated.style.plate.with(
  number: [Plate IX],
  title: [Variable-radius Tubes],
  subtitle: [sampled profiles and hemispherical end caps],
  margin: (x: 18mm, y: 16mm),
)

#let centerline(t) = (
  3.2 * (t - 0.5),
  0.35 * calc.sin(2 * calc.pi * t),
  0.45 * calc.sin(calc.pi * t),
)

#let radius-profile(t) = 0.12 + 0.34 * calc.pow(calc.sin(calc.pi * t), 2)

#let render-tube(shape, caption) = [
  #align(center)[
    #drawing.canvas({
      geo.render(
        shape,
        eye: (4.8, 7.2, 3.8),
        center: (0.0, 0.0, 0.1),
        width: 5.2,
        height: 3.4,
        fovy: 34,
        step: 0.014,
        pen: (0.020, 0.0055, 24deg),
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
  gutter: 9mm,
  render-tube(
    geo.tube-curve(
      centerline,
      radius: radius-profile,
      samples: 64,
      sides: 16,
      cap: "round",
      pattern: (geo.texture.lit-hatch)(
        light: (-1.0, -0.5, 1.0),
        count: 280,
        length: 0.18,
        crosshatch: 0.8,
        seed: 31,
      ),
    ),
    [Fig. 1. Functional radius profile with round caps.],
  ),
  render-tube(
    geo.tube(
      ((-1.6, 0.0, 0.0), (-0.7, 0.15, 0.25), (0.2, -0.1, 0.4), (1.0, 0.1, 0.2), (1.6, 0.0, 0.0)),
      radius: (0.12, 0.24, 0.46, 0.3, 0.16),
      sides: 16,
      cap: "round",
      pattern: (geo.texture.striped)(26),
    ),
    [Fig. 2. One radius supplied for each centerline point.],
  ),
)

#v(8mm)

#premetadated.style.notes(
  premetadated.style.note([Profiles.], [
    `tube` accepts a scalar or one radius per point. `tube-curve` additionally
    accepts a function evaluated at each sampled curve parameter.
  ]),
  premetadated.style.note([End caps.], [
    Open tubes accept `cap: "flat"`, `"round"`, or `"none"`. A round cap is an
    integrated hemisphere using the endpoint radius and tangent.
  ]),
)
