#import "../lib.typ" as premetadated

#let stroke = premetadated.stroke
#let geometry = premetadated.geometry
#let drawing = premetadated.illustration

#let line = (
  ((0.0, 0.0), (1.0, 0.0), (2.0, 0.0), (3.0, 0.0)),
)
#let polygons = stroke.envelope(line, pen: (0.4, 0.15, 25deg))
#assert.eq(polygons.len(), 1)
#assert(polygons.first().len() >= 16)

#let projected = geometry.paths(
  geometry.torus((0.0, 0.0, 0.0), 0.7, 0.22),
  eye: (4.0, 5.0, 3.0),
  width: 5.0,
  height: 4.0,
)
#assert(projected.len() > 0)

#let tau = 2 * calc.pi
#let trefoil(t) = (
  (2 + calc.cos(3 * t)) * calc.cos(2 * t),
  (2 + calc.cos(3 * t)) * calc.sin(2 * t),
  calc.sin(3 * t),
)
#let knot = geometry.tube-curve(
  trefoil,
  start: 0.0,
  end: tau,
  samples: 48,
  sides: 8,
  radius: 0.16,
  closed: true,
)
#assert(geometry.paths(knot, eye: (7.0, 9.0, 6.0), width: 11.0, height: 8.0).len() > 0)

#let new-solids = (
  geometry.ellipsoid((-1.2, 0.0, 0.0), (1.0, 0.6, 0.8)),
  geometry.rounded-box((0.0, -0.7, -0.6), (1.3, 0.7, 0.6), radius: 0.18),
  geometry.rounded-polyhedron(
    ((2.0, -0.7, -0.6), (3.3, -0.7, -0.6), (2.65, 0.8, -0.6), (2.65, 0.0, 0.8)),
    radius: 0.16,
  ),
)
#assert(geometry.paths(..new-solids, eye: (5.0, 7.0, 4.0), width: 9.0, height: 5.0).len() > 0)

#show: premetadated.style.example.with(width: 8cm, height: 4cm, margin: 5mm)
#drawing.canvas({
  stroke.nib-stroke(line, pen: (0.4, 0.15, 25deg), fill: rgb("d1495b"))
})