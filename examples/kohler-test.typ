#import "../lib.typ" as premetadated

#let drawing = premetadated.illustration
#let pale-ink = drawing.palette.pale-ink
#let optics-illustration = premetadated.optics-illustration

#let diagram = optics-illustration.import-scene(
  json("../assets/rayscenes/test.json"),
  beam-rays: 11,
  angle-rays: 3,
  scale: 70,
  max-distance: 1200,
  max-interactions: 8,
)

#show: premetadated.style.plate.with(
  number: [Plate IX],
  title: [Köhler Illumination],
  subtitle: [rays computed from a Ray Optics Simulation scene],
  margin: (top: 22mm, bottom: 22mm, left: 20mm, right: 20mm),
)
#show math.equation: set text(font: ("Old Standard", "New Computer Modern Math"))

#let kohler-figure = drawing.canvas(length: 1.18cm, {
  optics-illustration.draw(diagram)
  optics-illustration.label(diagram, (58.5, 590), [extended source])
  optics-illustration.label(diagram, (177, 300), [field stop])
  optics-illustration.label(diagram, (611, 215), [aperture stop])
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
    The scene is read directly from `assets/rayscenes/test.json`. Pixel
    coordinates are retained for the optical calculation and transformed only
    when the finished traces are engraved on the plate.
  ]),
  premetadated.style.note([Interpretation.], [
    The first lens images the extended source toward the aperture stop. The
    second lens redirects the admitted pencil after the stop; blocked rays end at
    the opaque leaves rather than passing through them.
  ]),
)

#v(5mm)
#line(length: 100%, stroke: (paint: pale-ink, thickness: 0.35pt))
#v(3mm)
#align(center, text(size: 9pt, tracking: 1.1pt, smallcaps[Principal Relations]))
#v(3mm)

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 10mm,
  align: top,
  [
    #text(size: 8pt, smallcaps[Conjugate planes])
    #v(2mm)
    $ 1/f = 1/s + 1/s' $
    #v(1mm)
    $ m = h'/h = -s'/s $
    #v(1mm)
    $ u_"out" = u_"in" - h/f $
    #v(2mm)
    #text(size: 8pt)[The second relation is the local paraxial update used by the tracer.]
  ],
  [
    #text(size: 8pt, smallcaps[Reflection])
    #v(2mm)
    $ bold(r) = bold(d) - 2 (bold(d) dot bold(n)) bold(n) $
    #v(1mm)
    $ norm(bold(r)) = 1 $
    #v(2mm)
    #text(size: 8pt)[The unit normal is taken from the finite mirror segment at incidence.]
  ],
  [
    #text(size: 8pt, smallcaps[Stops and source])
    #v(2mm)
    $ chi_"pass"(h) = cases(1 & abs(h) <= a, 0 & abs(h) > a) $
    #v(1mm)
    $ theta_j = -alpha/2 + j alpha/(N_theta - 1) $
    #v(2mm)
    #text(size: 8pt)[Opaque leaves reject rays outside the clear half-aperture $a$.]
  ],
)
