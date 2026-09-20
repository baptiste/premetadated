#import "illustration.typ": palette

#let example(
  body,
  width: 210mm,
  height: auto,
  margin: 12mm,
  paper: white,
  ink: black,
  font: "New Computer Modern",
) = {
  set page(width: width, height: height, margin: margin, fill: paper)
  set text(font: font, size: 10pt, fill: ink)
  body
}

#let plate(
  body,
  title: none,
  subtitle: none,
  number: none,
  paper: palette.paper,
  ink: palette.ink,
  margin: (x: 20mm, y: 18mm),
  title-gap: 8mm,
) = {
  assert(title != none, message: "plate title is required")
  set page(width: 210mm, height: 297mm, margin: margin, fill: paper)
  set text(font: "IM FELL Double Pica PRO", size: 10pt, fill: ink)
  set par(justify: true, leading: 0.62em)

  align(center)[
    #if number != none {
      text(size: 8.5pt, tracking: 1.5pt, smallcaps(number))
      v(2pt)
    }
    #text(size: 17pt)[#title]
    #if subtitle != none {
      v(1pt)
      text(size: 9pt, style: "italic", subtitle)
    }
  ]
  v(title-gap)
  body
}

#let patent(
  body,
  title: none,
  subtitle: none,
  office: [United States Patent Office],
  number: none,
  date: none,
  paper: rgb("f5eddf"),
  ink: rgb("221e1a"),
  margin: (top: 17mm, bottom: 18mm, left: 21mm, right: 21mm),
) = {
  assert(title != none, message: "patent title is required")
  set page(width: 210mm, height: 297mm, margin: margin, fill: paper)
  set text(font: "IM FELL Double Pica PRO", size: 10pt, fill: ink)
  set par(justify: true, leading: 0.62em)

  grid(
    columns: (1fr, 1fr),
    align: (left, right),
    [
      #text(size: 8pt, tracking: 1.2pt, smallcaps(office))
      #v(3pt)
      #text(size: 16pt)[#title]
      #if subtitle != none {
        v(2pt)
        text(size: 9pt, style: "italic", subtitle)
      }
    ],
    align(right)[
      #if number != none { text(size: 8pt, smallcaps(number)) }
      #if number != none and date != none { linebreak() }
      #if date != none { text(size: 8pt, date) }
    ],
  )
  v(5mm)
  line(length: 100%, stroke: (paint: ink, thickness: 0.35pt))
  v(10mm)
  body
}

#let notes(..items, gutter: 12mm) = grid(
  columns: (1fr,) * items.pos().len(),
  gutter: gutter,
  ..items.pos(),
)

#let note(heading, body) = [
  #text(size: 9pt, smallcaps(heading))
  #h(0.3em)
  #body
]
