#import "../lib.typ" as premetadated

#let geo = premetadated.geometry
#let drawing = premetadated.illustration
#let ink = drawing.palette.ink
#let light = (1.0, -0.4, 1.1)

#show: premetadated.style.plate.with(
  number: [Plate IX],
  title: [Ellipsoids and Rounded Polyhedra],
  subtitle: [affine quadrics and convex solids enlarged by a spherical radius],
  margin: (x: 19mm, y: 17mm),
)

#let lit = (geo.texture.lit-hatch)(
  light: light,
  count: 720,
  length: 0.22,
  crosshatch: 0.78,
  seed: 37,
)

#let render-shape(shape, caption, eye: (5.0, 6.5, 4.0), pen: (0.022, 0.006, 24deg)) = [
  #align(center)[
    #drawing.canvas({
      geo.render(
        shape,
        eye: eye,
        center: (0.0, 0.0, 0.0),
        width: 5.0,
        height: 4.2,
        fovy: 35.0,
        step: 0.016,
        pen: pen,
        epsilon: 0.003,
        fill: ink,
      )
    })
    #v(1mm)
    #drawing.figure-caption(caption)
  ]
]

#let tetrahedron = (
  (-1.0, -0.75, -0.7),
  (1.0, -0.75, -0.7),
  (0.0, 1.0, -0.7),
  (0.0, 0.0, 1.0),
)

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 7mm,
  render-shape(
    geo.ellipsoid((0.0, 0.0, 0.0), (1.35, 0.72, 0.86), pattern: lit),
    [Fig. 1. Triaxial ellipsoid.],
  ),
  render-shape(
    geo.ellipsoid(
      (0.0, 0.0, 0.0),
      (0.72, 0.72, 1.35),
      pattern: (geo.texture.lat-lng)(latitudes: 12, longitudes: 16),
    ),
    [Fig. 2. Prolate spheroid.],
  ),
  render-shape(
    geo.ellipsoid(
      (0.0, 0.0, 0.0),
      (1.35, 1.35, 0.48),
      pattern: (geo.texture.lit-stipple)(
        light: light,
        count: 6200,
        min-size: 0.003,
        max-size: 0.028,
        gamma: 1.0,
        distribution: "random",
        seed: 53,
      ),
    ),
    [Fig. 3. Oblate spheroid, stippled.],
    pen: (0.017, 0.005, 24deg),
  ),
)

#v(12mm)

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 7mm,
  render-shape(
    geo.rounded-box((-1.0, -0.75, -0.65), (1.0, 0.75, 0.65), radius: 0.10, detail: 32),
    [Fig. 4. Slightly rounded box.],
  ),
  render-shape(
    geo.rounded-box(
      (-0.85, -0.65, -0.55),
      (0.85, 0.65, 0.55),
      radius: 0.34,
      detail: 40,
      pattern: (geo.texture.striped)(1),
    ),
    [Fig. 5. Rounded box, construction mesh.],
    pen: (0.012, 0.004, 24deg),
  ),
  render-shape(
    geo.rounded-polyhedron(tetrahedron, radius: 0.24, detail: 40),
    [Fig. 6. Rounded tetrahedron.],
  ),
)

#v(13mm)

#premetadated.style.notes(
  premetadated.style.note([Ellipsoids.], [
    Sphere geometry is scaled independently along three axes, so hidden-line
    removal and every sphere texture remain available without another renderer.
  ]),
  premetadated.style.note([Rounded solids.], [
    The rounded polyhedron is the convex hull of spherical support samples around
    the supplied vertices, approximating the Premetadated sum $"conv"(V) + B_r$.
  ]),
)
