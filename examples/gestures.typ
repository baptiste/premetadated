#import "../lib.typ" as premetadated

#let drawing = premetadated.illustration
#let ink = drawing.palette.ink
#let pale = drawing.palette.pale-ink

#show: premetadated.style.plate.with(
  number: [Plate X],
  title: [Eyes and Indicative Hands],
  subtitle: [engraved observation and physical direction],
  margin: (x: 21mm, y: 18mm),
)

#let arrow(start, end, color: pale) = {
  let (x0, y0) = start
  let (x1, y1) = end
  let angle = calc.atan2(y1 - y0, x1 - x0)
  let wing = 0.17
  drawing.engraved(drawing.line-path(start, end), width: 0.010, ink: color)
  drawing.engraved(drawing.line-path(end, (x1 - wing * calc.cos(angle - 25deg), y1 - wing * calc.sin(angle - 25deg))), width: 0.010, ink: color)
  drawing.engraved(drawing.line-path(end, (x1 - wing * calc.cos(angle + 25deg), y1 - wing * calc.sin(angle + 25deg))), width: 0.010, ink: color)
}

#let pointing-arrow(anchors) = {
  let (px, py) = anchors.palm
  let (fx, fy) = anchors.finger
  let length = calc.sqrt(calc.pow(fx - px, 2) + calc.pow(fy - py, 2))
  arrow((fx, fy), (fx + 0.82 * (fx - px) / length, fy + 0.82 * (fy - py) / length))
}

#align(center)[
  #drawing.canvas({
    drawing.eye(origin: (-4.4, 0), direction: -18deg, size: 0.84)
    drawing.eye(origin: (-2.5, 0), direction: 0deg, size: 0.96)
    drawing.eye(origin: (-0.3, 0), direction: 14deg, size: 0.82)
    drawing.eye(origin: (1.9, 0), view: "profile", size: 0.86)
    drawing.eye(origin: (4.2, 0), view: "profile", side: "left", direction: -8deg, size: 0.78)
  })
  #drawing.figure-caption([Fig. 1. Frontal eyes and anatomical profile cutaways.])
]

#v(10mm)

#grid(
  columns: (1fr, 1fr),
  gutter: 12mm,
  align(center)[
    #drawing.canvas({
      let anchors = drawing.hand-anchors(pose: "point", origin: (-0.5, 0), direction: 5deg, size: 1.2)
      drawing.hand(pose: "point", origin: (-0.5, 0), direction: 5deg, size: 1.2)
      pointing-arrow(anchors)
    })
    #drawing.figure-caption([Fig. 2. The pointing hand.])
  ],
  align(center)[
    #drawing.canvas({
      let anchors = drawing.hand-anchors(pose: "point", origin: (0.5, 0), direction: 175deg, size: 1.2, handedness: "left")
      drawing.hand(pose: "point", origin: (0.5, 0), direction: 175deg, size: 1.2, handedness: "left")
      pointing-arrow(anchors)
    })
    #drawing.figure-caption([Fig. 3. Mirrored and revolved.])
  ],
)

#v(12mm)

#align(center)[
  #drawing.canvas({
    let anchors = drawing.hand-anchors(pose: "right-hand-rule", origin: (0, -0.15), size: 1.18)
    drawing.hand(pose: "right-hand-rule", origin: (0, -0.15), size: 1.18)
    arrow(anchors.palm, (anchors.finger.at(0), anchors.finger.at(1) + 0.62), color: ink)
    arrow(anchors.palm, (anchors.thumb.at(0) + 0.55, anchors.thumb.at(1)), color: ink)
    drawing.label((anchors.finger.at(0) + 0.18, anchors.finger.at(1) + 0.55), [$B$])
    drawing.label((anchors.thumb.at(0) + 0.55, anchors.thumb.at(1) + 0.18), [$v$])
  })
  #drawing.figure-caption([Fig. 4. Raised-hand placeholder with reusable vector anchors.])
]

#v(10mm)

#premetadated.style.notes(
  premetadated.style.note([Construction.], [
    The eyes combine filled Cetz pupils with asymmetric cubic eyelids, creases,
    and lashes swept by the package's elliptical nib. Profile views expose the
    cornea, iris, lens, vitreous chamber, and optic nerve.
  ]),
  premetadated.style.note([Handedness.], [
    Set `handedness: "left"` to mirror either pose; `direction` then revolves the
    complete hand SVG and its vector anchors.
  ]),
)