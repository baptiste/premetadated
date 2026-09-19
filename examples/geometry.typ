#import "../lib.typ" as premetadated

#let ln = premetadated.geometry
#let drawing = premetadated.illustration

#show: premetadated.style.example.with(
  width: 7cm,
  height: 5cm,
  margin: 5mm,
  paper: rgb("f4f0e6"),
  ink: drawing.palette.ink,
)

#align(center + horizon, drawing.canvas({
  ln.render(
    ln.sphere((0.0, 0.0, 0.0), 1.25, pattern: (ln.texture.lat-lng)(latitudes: 9, longitudes: 12)),
    ln.sphere((1.7, 0.1, -0.1), 0.72, pattern: (ln.texture.random-equators)(17, count: 18)),
    ln.cylinder(0.38, (-1.8, -0.7, -1.0), (-1.8, -0.7, 1.0), pattern: (ln.texture.striped)(14)),
    eye: (4.8, 6.0, 3.7),
    center: (0.0, 0.0, 0.0),
    width: 14.0,
    height: 8.0,
    fovy: 42.0,
    pen: (0.035, 0.002, 63deg),
    fill: rgb("25221d"),
  )
}))