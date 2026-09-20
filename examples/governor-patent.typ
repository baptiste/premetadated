#import "../lib.typ" as premetadated

#let ln = premetadated.geometry
#let mechanics = premetadated.mechanics
#let drawing = premetadated.illustration
#let ink = rgb("221e1a")

#show: premetadated.style.patent.with(
	title: [Centrifugal Governor],
	subtitle: [Improvement in regulators for rotary engines],
	number: [No. 48,317],
	date: [Patented June 20, 1865],
)

#let lit-ball(center, seed) = mechanics.lit-joint(
	center,
	radius: 0.42,
	light: (-1.0, -0.7, 1.4),
	count: 420,
	crosshatch: 0.68,
	seed: seed,
)

#let governor = (
	mechanics.rod((0.0, 0.0, -1.6), (0.0, 0.0, 2.15), radius: 0.085, pattern: (ln.texture.striped)(12)),
	mechanics.collar((0.0, 0.0, 1.72), (0.0, 0.0, 2.02), radius: 0.24, stripes: 16),
	mechanics.collar((0.0, 0.0, -0.72), (0.0, 0.0, -0.34), radius: 0.20, stripes: 16),
	mechanics.rod((0.0, 0.0, 1.76), (-1.12, 0.0, 0.34), radius: 0.07),
	mechanics.rod((0.0, 0.0, 1.76), (1.12, 0.0, 0.34), radius: 0.07),
	mechanics.rod((0.0, 0.0, -0.38), (-1.12, 0.0, 0.34), radius: 0.055),
	mechanics.rod((0.0, 0.0, -0.38), (1.12, 0.0, 0.34), radius: 0.055),
	lit-ball((-1.22, 0.0, 0.20), 31),
	lit-ball((1.22, 0.0, 0.20), 47),
	ln.cube((-0.72, -0.58, -1.82), (0.72, 0.58, -1.60), pattern: (ln.texture.striped)(10)),
)

#let view(eye, title) = [
	#align(center)[
		#drawing.canvas({
			ln.render(
				..governor,
				eye: eye,
				center: (0.0, 0.0, 0.15),
				width: 7.2,
				height: 9.0,
				fovy: 31.0,
				step: 0.018,
				pen: (0.026, 0.007, 25deg),
				epsilon: 0.003,
				fill: ink,
			)
		})
		#v(2mm)
		#text(size: 9pt, style: "italic")[#title]
	]
]

#grid(
	columns: (1fr, 1fr),
	gutter: 12mm,
	view((4.8, 6.5, 3.0), [Fig. 1. Perspective elevation.]),
	view((6.8, 1.6, 2.4), [Fig. 2. Transverse elevation.]),
)

#v(9mm)

#grid(
	columns: (1fr, 1fr),
	gutter: 13mm,
	[
		#text(size: 9pt, smallcaps[Specification.])
		#h(0.35em)
		The upright spindle carries a sliding collar connected by paired links to
		the weighted arms. As the velocity increases, the balls rise outward and
		the collar follows, communicating the motion to the regulating valve.

		#v(5mm)
		The two views are projections of one geometric assembly. Occluded portions
		are removed before drawing, so no hidden stroke has been erased by hand.
	],
	[
		#text(size: 9pt, smallcaps[Claim.])
		#h(0.35em)
		The combination of spindle, sliding collar, jointed arms, and opposed
		weighted balls, substantially in the disposition shown and for the purpose
		herein described.

		#v(8mm)
		#align(right)[
			#text(size: 8pt, smallcaps[Witnesses:])
			#v(3pt)
			#text(font: "IM FELL Double Pica PRO", size: 13pt, style: "italic")[E. Cartwright]
			#linebreak()
			#text(font: "IM FELL Double Pica PRO", size: 13pt, style: "italic")[M. Bell]
		]
	],
)

#v(1fr)

#align(right)[
	#text(size: 8pt, smallcaps[Inventor:])
	#v(3pt)
	#text(font: "IM FELL Double Pica PRO", size: 15pt, style: "italic")[John Hargreave]
]
