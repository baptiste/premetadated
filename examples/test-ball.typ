#import "../lib.typ" as premetadated

#let ln = premetadated.geometry
#let drawing = premetadated.illustration
#let ink = drawing.palette.ink

// #show: premetadated.style.plate.with(
//   number: [Plate VII],
//   title: [The Phases of the Moon],
//   subtitle: [shown by one sphere under eight directions of the solar light],
//   margin: (x: 22mm, y: 20mm),
//   title-gap: 10mm,
// )
// 
#set page(width:auto, height:auto, margin:2mm)


  #align(center)[
    #drawing.canvas({
      ln.render(
        ln.sphere(
          (0.0, 0.0, 0.0),
          1.0,
          pattern: (ln.texture.lit-stipple)(
            light: (-1.0, -0.50, 0.0),
            count: 800,
            min-size: 0.0003,
            max-size: 0.015,
            gamma: 0.8995,
            distribution: "random",
            seed: 31,
          ),
        ),
        eye: (0.0, -5.0, 0.35),
        center: (0.0, 0.0, 0.0),
        up: (0.0, 0.0, 1.0),
        width: 1.0,
        height: 1.0,
        fovy: 31.0,
        step: 0.02,
        pen: (0.0017, 0.00015, 60deg),
        pressure: (
          minimum-axis: 0.0011,
          period: 0.0025,
          seed: 31,
        ),
        epsilon: 0.005,
        fill: ink,
      )
    })
  ]



