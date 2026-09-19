#import "../lib.typ" as premetadated

#let stroke = premetadated.stroke
#let geometry = premetadated.geometry
#let drawing = premetadated.illustration
#let optics = premetadated.optics
#let optics-illustration = premetadated.optics-illustration

#let lens-trace = optics.trace-ray(
  optics.ray((-2.0, 1.0), (1.0, 0.0)),
  (optics.ideal-lens((0.0, -2.0), (0.0, 2.0), 2.0),),
  max-distance: 4.0,
).first()
#assert.eq(lens-trace.points.len(), 3)
#let lens-hit = lens-trace.points.at(1)
#let lens-end = lens-trace.points.at(2)
#let focal-y = lens-hit.at(1) + (2.0 - lens-hit.at(0)) * (lens-end.at(1) - lens-hit.at(1)) / (lens-end.at(0) - lens-hit.at(0))
#assert(calc.abs(focal-y) < 1e-5)

#let mirror-trace = optics.trace-ray(
  optics.ray((-1.0, 0.0), (1.0, 0.0)),
  (optics.mirror((0.0, -1.0), (0.0, 1.0)),),
  max-distance: 2.0,
).first()
#assert(mirror-trace.points.last().at(0) < 0)

#let blocker-trace = optics.trace-ray(
  optics.ray((-1.0, 0.0), (1.0, 0.0)),
  (optics.blocker((0.0, -1.0), (0.0, 1.0)),),
).first()
#assert.eq(blocker-trace.terminated-by, "blocker")
#assert.eq(blocker-trace.points.len(), 2)

#let stop = optics.aperture((0.0, -2.0), (0.0, 2.0), (0.0, -0.5), (0.0, 0.5))
#assert.eq(optics.trace-ray(optics.ray((-1.0, 0.0), (1.0, 0.0)), (stop,), max-distance: 2.0).first().terminated-by, "distance")
#assert.eq(optics.trace-ray(optics.ray((-1.0, 1.0), (1.0, 0.0)), (stop,)).first().terminated-by, "aperture")

#let split-traces = optics.trace-ray(
  optics.ray((-1.0, 0.0), (1.0, 0.0)),
  (optics.beam-splitter((0.0, -1.0), (0.0, 1.0)),),
  max-distance: 2.0,
)
#assert.eq(split-traces.len(), 2)

#let imported-kohler = optics.import-ray-optics(json("../assets/rayscenes/kohler.json"), beam-rays: 3, angle-rays: 2)
#assert.eq(imported-kohler.rays.len(), 6)
#assert.eq(imported-kohler.elements.len(), 4)
#assert(imported-kohler.bounds != none)

#let imported-point = optics.import-ray-optics((
  objs: ((type: "PointSource", x: 3.0, y: 4.0, brightness: 0.6),),
), beam-rays: 3, angle-rays: 2)
#assert.eq(imported-point.rays.len(), 6)
#assert.eq(imported-point.rays.first().origin, (3.0, 4.0))

#let imported-diagram = optics-illustration.import-scene((
  objs: (
    (type: "Beam", p1: (x: -3.0, y: -0.4), p2: (x: -3.0, y: 0.4)),
    (type: "IdealLens", p1: (x: -1.0, y: -1.0), p2: (x: -1.0, y: 1.0), focalLength: 2.0),
    (type: "Mirror", p1: (x: 1.0, y: -0.7), p2: (x: 1.0, y: 0.7)),
    (type: "Blocker", p1: (x: 2.0, y: -0.7), p2: (x: 2.0, y: 0.7)),
    (type: "CropBox", p1: (x: -4.0, y: -2.0), p4: (x: 4.0, y: 2.0)),
  ),
), beam-rays: 2, angle-rays: 1, scale: 1.2, max-distance: 8)
#assert.eq(imported-diagram.traces.len(), 2)
#assert.eq(optics-illustration.project(imported-diagram, imported-diagram.center), (0.0, 0.0))

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
  optics-illustration.draw(imported-diagram)
})