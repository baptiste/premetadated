#import "@preview/cetz:0.4.2"
#import "../lib.typ" as premetadated

#let nib-stroke = premetadated.stroke.nib-stroke

#show: premetadated.style.example.with(width: 22cm)

#let wave = (
  ((0, 0), (1, 1.8), (2.8, -1.8), (4, 0)),
)

#let loop = (
  ((0, 0), (0.8, -1.2), (3.2, -1.2), (4, 0)),
  ((4, 0), (3.2, 1.8), (0.8, 1.8), (0, 0)),
)

#let example(title, body) = figure(
  cetz.canvas(length: 1cm, body),
  caption: title,
)

= Elliptical pen envelopes

#grid(
  columns: (1fr, 1fr),
  gutter: 10mm,
  row-gutter: 8mm,
  example([Fixed elliptical nib], {
    nib-stroke(
      wave,
      pen: (0.38, 0.10, 30deg),
      fill: rgb("d1495b"),
    )
  }),
  example([Circular pen], {
    nib-stroke(
      wave,
      pen: (0.20, 0.20, 0deg),
      fill: rgb("2878b5"),
    )
  }),
  example([Nib rotating through 360 degrees], {
    nib-stroke(
      (((0, 0), (4 / 3, 0), (8 / 3, 0), (4, 0)),),
      pen: (
        mode: "explicit",
        samples: (
          (arclength: 0, a: 0.42, b: 0.09, angle: 0deg),
          (arclength: 4, a: 0.42, b: 0.09, angle: 360deg),
        ),
      ),
      fill: rgb("e6a532"),
    )
  }),
  example([Calligraphic dashed stroke], {
    nib-stroke(
      wave,
      pen: (
        mode: "calligraphic",
        offset: 25deg,
        samples: (
          (arclength: 0, a: 0.34, b: 0.08),
        ),
      ),
      dash: (
        lengths: (0.65, 0.25),
        jitter: 0.04,
        seed: 42,
      ),
      fill: rgb("3a936b"),
    )
  }),
  example([Closed elliptical band], {
    nib-stroke(
      loop,
      closed: true,
      pen: (0.25, 0.10, 45deg),
      fill: rgb("7455a6"),
    )
  }),
)

#pagebreak()

  // path,
  // pen: none,
  // closed: false,
  // dash: none,
  // pressure: none,
  // epsilon: 0.01,
  // fill: black,
  // stroke: none,

#example([Fixed elliptical nib], {
    nib-stroke(
      wave,
      pen: (0.38, 0.10, 30deg),
      fill: rgb("d1495b"),
    )
  })