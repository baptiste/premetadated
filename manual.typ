#import "lib.typ" as premetadated

#let stroke = premetadated.stroke
#let geo = premetadated.geometry
#let draw = premetadated.illustration
#let optics = premetadated.optics
#let mechanics = premetadated.mechanics

#set document(title: "Premetadated Manual", author: "Baptiste Auguie")
#set page(paper: "a4", margin: (x: 24mm, y: 22mm), numbering: "1")
#set text(size: 10pt, fill: rgb("272119"))
#set par(justify: true, leading: 0.72em)
#set heading(numbering: "1.")
#show link: set text(fill: rgb("315f72"))
#show raw.where(block: true): body => block(
  inset: 8pt,
  fill: rgb("f3ead9"),
  stroke: rgb("cbbda6"),
  radius: 2pt,
  body,
)

#align(center)[
  #v(24mm)
  #text(size: 30pt, weight: "bold", smallcaps[Premetadated])
  #v(4mm)
  #text(size: 13pt, style: "italic")[Vintage scientific illustration for Typst]
  #v(14mm)
  #draw.canvas(length: 0.82cm, {
    geo.render(
      geo.sphere(
        (-1.25, 0, 0),
        0.82,
        pattern: (geo.texture.lit-hatch)(light: (-1, -0.4, 1), count: 420, crosshatch: 0.72),
      ),
      geo.torus((1.20, 0, 0), 0.72, 0.23, pattern: (geo.texture.striped)(24)),
      eye: (4.2, 5.0, 3.1),
      width: 5.3,
      height: 3.4,
      pen: (0.022, 0.006, 24deg),
    )
  })
  #v(15mm)
  Version 0.1.0

  #v(4mm)
  #link("https://github.com/baptiste/premetadated")[github.com/baptiste/premetadated]
]

#pagebreak()
#outline(title: [Contents], indent: auto)

#pagebreak()
= Overview

Premetadated is a drawing toolkit for historical-looking scientific figures. It
combines Typst and Cetz for page composition with a bundled Rust/WASM engine for
elliptical-pen envelopes, 3D projection, hidden-line removal, and robust solid
geometry. Output remains vector-based: labels are Typst text and marks are Cetz
paths rather than raster effects.

The package entrypoint exports seven namespaces: `stroke`, `geometry`,
`illustration`, `optics`, `optics-illustration`, `mechanics`, and `style`. Most
documents need only the geometry and illustration namespaces.

== Importing

From a repository checkout:

```typ
#import "lib.typ" as premetadated
#let geo = premetadated.geometry
#let draw = premetadated.illustration
```

For a future Typst Universe release, use:

```typ
#import "@preview/premetadated:0.1.0"
```

The checked-in WASM plugin is loaded internally. Users do not need Rust unless
they modify the geometry engine.

= The drawing model

Two representations meet in the package:

- A 2D path is an array of cubic Bézier segments. Each segment is
  `(P0, P1, P2, P3)`, where every point is an `(x, y)` pair.
- A 3D scene is a list of shape dictionaries. `geometry.render` projects their
  visible paths and applies the same elliptical nib to each polyline.

Drawing helpers are intended to run inside `illustration.canvas`, whose default
unit is one centimetre.

#align(center)[
  #draw.canvas(length: 0.78cm, {
    draw.engraved(
      (((0, 0), (0.8, 1.4), (2.7, -1.1), (4, 0.2)),),
      width: 0.022,
    )
    draw.label((0, -0.25), [$P_0$])
    draw.label((4, -0.05), [$P_3$])
  })
  #draw.figure-caption([A cubic path rendered as an elliptical-nib rule.])
]

```typ
#draw.canvas({
  draw.engraved(draw.line-path((0, 0), (4, 1)))
})
```

= Elliptical-nib strokes

`stroke.nib-stroke` sweeps an ellipse along a cubic path and fills the resulting
envelope. A constant pen is `(major-axis, minor-axis, angle)`.

#align(center)[
  #draw.canvas(length: 0.9cm, {
    stroke.nib-stroke(
      (((0, 0), (1, 1.25), (2.3, -1.0), (3.5, 0.15)),),
      pen: (0.30, 0.075, 24deg),
      fill: draw.palette.ink,
    )
  })
]

```typ
stroke.nib-stroke(
  (((0, 0), (1, 1.25), (2.3, -1), (3.5, 0.15)),),
  pen: (0.30, 0.075, 24deg),
  fill: black,
)
```

Use `closed: true` for a closed centreline. `epsilon` controls Bézier flattening;
smaller values produce a finer envelope. `stroke.envelope` returns polygon data
without drawing it.

== Variable pens

Explicit samples interpolate axes and angle by arclength:

#grid(
  columns: (1fr, 1fr),
  gutter: 8mm,
  align: center,
  [
    #draw.canvas(length: 0.72cm, {
      stroke.nib-stroke(
        (((0, 0), (1.1, 1.25), (2.6, -1.0), (4, 0.1)),),
        pen: (
          mode: "explicit",
          samples: (
            (arclength: 0, a: .38, b: .075, angle: 5deg),
            (arclength: 4.8, a: .15, b: .04, angle: 115deg),
          ),
        ),
        fill: draw.palette.ink,
      )
    })
    #draw.figure-caption([Explicit interpolation])
  ],
  [
    #draw.canvas(length: 0.72cm, {
      stroke.nib-stroke(
        (((0, 0), (1.1, 1.25), (2.6, -1.0), (4, 0.1)),),
        pen: (
          mode: "calligraphic",
          offset: 20deg,
          samples: ((arclength: 0, a: .30, b: .065),),
        ),
        fill: draw.palette.ink,
      )
    })
    #draw.figure-caption([Tangent-following calligraphy])
  ],
)

```typ
pen: (
  mode: "explicit",
  samples: (
    (arclength: 0, a: .32, b: .06, angle: 15deg),
    (arclength: 4, a: .16, b: .04, angle: 65deg),
  ),
)
```

Calligraphic samples derive orientation from the path tangent:

```typ
pen: (
  mode: "calligraphic",
  offset: 20deg,
  samples: ((arclength: 0, a: .28, b: .07),),
)
```

== Dashes and pressure

A dash dictionary accepts `lengths`, `offset`, `jitter`, and `seed`. Pressure
clamps the smallest printable nib axis and represents lighter requests with a
deterministic broken duty cycle.

#grid(
  columns: (1fr, 1fr),
  gutter: 8mm,
  align: center,
  [
    #draw.canvas(length: 0.68cm, {
      stroke.nib-stroke(
        (((0, 0), (1.2, 0.8), (2.8, -0.8), (4, 0)),),
        pen: (0.22, 0.055, 28deg),
        dash: (lengths: (0.48, 0.20), jitter: 0.04, seed: 7),
        fill: draw.palette.ink,
      )
    })
    #draw.figure-caption([Seeded irregular dashes])
  ],
  [
    #draw.canvas(length: 0.68cm, {
      stroke.nib-stroke(
        (((0, 0), (1.33, 0), (2.67, 0), (4, 0)),),
        pen: (
          mode: "explicit",
          samples: (
            (arclength: 0, a: .22, b: .075, angle: 18deg),
            (arclength: 4, a: .025, b: .008, angle: 18deg),
          ),
        ),
        pressure: (minimum-axis: 0.028, period: 0.30, seed: 17),
        fill: draw.palette.ink,
      )
    })
    #draw.figure-caption([Pressure taper breaking into marks])
  ],
)

```typ
dash: (lengths: (0.32, 0.16), jitter: 0.04, seed: 7),
pressure: (minimum-axis: 0.028, period: 0.32, seed: 17),
```

= Three-dimensional geometry

Construct shapes, then pass them positionally to `geometry.render`.

#grid(
  columns: (1fr, 1fr),
  gutter: 8mm,
  align: center,
  ..(
    ((4.5, 5.2, 3.2), [Perspective camera]),
    ((6.5, 1.8, 2.6), [Low transverse camera]),
  ).map(((eye, caption)) => [
    #draw.canvas(length: 0.68cm, {
      geo.render(
        geo.sphere((-0.75, 0, 0), 0.78, pattern: (geo.texture.lat-lng)(latitudes: 7, longitudes: 10)),
        geo.cylinder(0.42, (0.85, 0, -0.8), (0.85, 0, 0.8), pattern: (geo.texture.striped)(12)),
        eye: eye,
        width: 4.2,
        height: 3.0,
        pen: (0.022, 0.006, 24deg),
      )
    })
    #draw.figure-caption(caption)
  ]),
)

```typ
#draw.canvas({
  geo.render(
    geo.sphere((0, 0, 0), 1),
    geo.cylinder(0.45, (-1.8, 0, -0.8), (-1.8, 0, 0.8)),
    eye: (4, 5, 3),
    center: (0, 0, 0),
    width: 6,
    height: 5,
    pen: (0.025, 0.007, 25deg),
  )
})
```

The camera parameters are `eye`, `center`, `up`, `width`, `height`, `fovy`,
`near`, `far`, and visibility sampling `step`. Use `geometry.paths` instead of
`render` when projected polylines are needed without nib rendering.

== Primitives

- `sphere(center, radius)` and `ellipsoid(center, radii)`
- `cube(min, max)` and `rounded-box(min, max, radius:)`
- `cylinder(radius, start, end)` and `cone(radius, base, apex)`
- `torus(center, major-radius, minor-radius)`
- `rounded-polyhedron(vertices, radius:, detail:)`
- `tube(points, radius:, sides:, closed:)`
- `tube-curve(function, start:, end:, samples:, radius:, sides:, closed:)`

Rounded polyhedra approximate the convex Minkowski sum of their input vertices
with a sphere. Their original convex-hull edges receive dedicated transition
bands so rounding remains legible without exposing triangulation diagonals.

#align(center)[
  #draw.canvas(length: 0.61cm, {
    geo.render(
      geo.sphere((-3.6, 0, 0), 0.62, pattern: (geo.texture.lat-lng)(latitudes: 6, longitudes: 9)),
      geo.ellipsoid((-2.15, 0, 0), (0.78, 0.48, 0.62), pattern: (geo.texture.outline)()),
      geo.cube((-1.25, -0.52, -0.52), (-0.25, 0.52, 0.52)),
      geo.cylinder(0.42, (0.55, 0, -0.65), (0.55, 0, 0.65), pattern: (geo.texture.striped)(10)),
      geo.cone(0.54, (1.75, 0, -0.65), (1.75, 0, 0.75), pattern: (geo.texture.striped)(11)),
      geo.torus((3.05, 0, 0), 0.52, 0.18, pattern: (geo.texture.striped)(14)),
      geo.rounded-box((3.9, -0.48, -0.45), (4.85, 0.48, 0.45), radius: 0.18, detail: 28),
      eye: (7, 9, 5),
      center: (0.55, 0, 0),
      width: 10.5,
      height: 3.0,
      fovy: 28,
      pen: (0.018, 0.005, 24deg),
    )
  })
  #draw.figure-caption([Sphere, ellipsoid, cube, cylinder, cone, torus, and rounded box.])
]

== Parametric tubes

```typ
#let tau = 2 * calc.pi
#let trefoil(t) = (
  (2 + calc.cos(3 * t)) * calc.cos(2 * t),
  (2 + calc.cos(3 * t)) * calc.sin(2 * t),
  calc.sin(3 * t),
)
#let knot = geo.tube-curve(
  trefoil,
  start: 0,
  end: tau,
  samples: 120,
  radius: 0.16,
  sides: 14,
  closed: true,
)
```

#let manual-tau = 2 * calc.pi
#let manual-trefoil(t) = (
  (2 + calc.cos(3 * t)) * calc.cos(2 * t),
  (2 + calc.cos(3 * t)) * calc.sin(2 * t),
  calc.sin(3 * t),
)
#let manual-knot = geo.tube-curve(
  manual-trefoil,
  start: 0,
  end: manual-tau,
  samples: 96,
  radius: 0.16,
  sides: 12,
  closed: true,
  pattern: (geo.texture.striped)(24),
)

#align(center)[
  #draw.canvas(length: 0.72cm, {
    geo.render(
      manual-knot,
      eye: (7, 9, 6),
      width: 6.5,
      height: 4.2,
      fovy: 32,
      step: 0.018,
      pen: (0.020, 0.0055, 24deg),
    )
  })
  #draw.figure-caption([A closed trefoil tube with hidden crossings removed.])
]

= Surface styles and light

Every shape accepts a `pattern`. General solid patterns are
`geometry.texture.outline`, `striped`, and `lit-hatch`. Spheres and ellipsoids
also support latitude/longitude grids, random equators, random circles, and
lighting-aware stippling.

```typ
pattern: (geo.texture.lit-hatch)(
  light: (-1.0, -0.5, 1.0),
  count: 560,
  length: 0.18,
  crosshatch: 0.72,
  seed: 11,
)
```

`count` is the number of candidate marks. `crosshatch` is the darkness threshold
for a second direction. All pseudo-random patterns are deterministic for a given
seed.

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 4mm,
  align: center,
  ..(
    ((geo.texture.lat-lng)(latitudes: 8, longitudes: 11), [Latitude / longitude]),
    ((geo.texture.lit-hatch)(light: (-1, -0.5, 1), count: 440, crosshatch: 0.72, seed: 11), [Lit hatch]),
    ((geo.texture.lit-stipple)(light: (-1, -0.5, 1), count: 2600, min-size: 0.005, max-size: 0.030, distribution: "random", seed: 11), [Lit stipple]),
  ).map(((pattern, caption)) => [
    #draw.canvas(length: 0.56cm, {
      geo.render(
        geo.sphere((0, 0, 0), 1, pattern: pattern),
        eye: (4.2, 5.2, 3),
        width: 3.2,
        height: 3.0,
        step: 0.020,
        pen: (0.017, 0.005, 24deg),
      )
    })
    #draw.figure-caption(caption)
  ]),
)

```typ
pattern: (geo.texture.lit-stipple)(
  light: (-1.0, -0.5, 1.0),
  count: 5200,
  min-size: 0.005,
  max-size: 0.032,
  gamma: 1.3,
  distribution: "fibonacci",
  seed: 11,
)
```

= Illustration helpers

`illustration.palette` provides `paper`, `ink`, and `pale-ink`. The most useful
helpers are:

- `canvas(body, length:)` creates a Cetz canvas.
- `line-path(start, end)` returns a straight cubic path.
- `engraved(path, width:, angle:, dash:, pressure:, epsilon:, ink:)` draws a
  narrow elliptical-nib rule.
- `label(point, body)` places a paper-backed label.
- `figure-caption(body)` formats a compact figure caption.

#align(center)[
  #draw.canvas(length: 0.72cm, {
    draw.engraved(draw.line-path((-3.0, -0.65), (3.0, -0.65)), width: 0.014)
    draw.label((-2.25, -0.32), [paper-backed label])
    draw.eye(origin: (-0.65, 0.15), direction: -12deg, size: 0.95)
    draw.hand(pose: "point", origin: (1.25, 0.05), direction: 4deg, size: 1.05)
    draw.hand(pose: "right-hand-rule", origin: (2.75, 0.05), direction: -8deg, size: 0.85, handedness: "left")
  })
  #draw.figure-caption([Engraved rule, label, eye, pointing hand, and mirrored raised hand.])
]

The `eye` and `hand` helpers currently place vendored Twemoji SVG placeholders.
They support origin, direction, and size; hands additionally support `pose` and
`handedness`. `hand-anchors` returns approximate wrist, palm, finger, and thumb
attachment coordinates for vector annotations.

= Optics and mechanics

The standalone `optics` module has no drawing dependency. Sources are created
with `ray`, `point-source`, or `beam-source`; elements with `ideal-lens`,
`mirror`, `blocker`, `aperture`, or `beam-splitter`. `trace-ray` and
`trace-scene` return point arrays and preserve brightness and wavelength
metadata. Splitters create independent transmitted and reflected branches.

At a lens the local paraxial slope follows $u' = u - h/f$. Mirrors use
$bold(r) = bold(d) - 2 (bold(d) dot bold(n)) bold(n)$. The tracer always selects
the nearest finite-segment intersection, while blockers and the opaque leaves
of an aperture terminate the ray.

#align(center)[
  #draw.canvas(length: 0.68cm, {
    let left-lens = optics.lens-path(-1.5, 1.05, 0.28)
    let right-lens = optics.lens-path(1.35, 0.86, 0.22)
    let scene = (
      rays: optics.beam-source((-4, -0.65), (-4, 0.65), count: 7, spread: 5deg, angle-count: 2),
      elements: (
        optics.ideal-lens((-1.5, -1.05), (-1.5, 1.05), 2.4),
        optics.ideal-lens((1.35, -0.86), (1.35, 0.86), 1.8),
      ),
    )
    let traces = optics.trace-scene(scene, max-distance: 3.0)
    stroke.nib-stroke(left-lens, closed: true, pen: (0.020, 0.006, 20deg), fill: draw.palette.ink)
    stroke.nib-stroke(right-lens, closed: true, pen: (0.020, 0.006, 20deg), fill: draw.palette.ink)
    for trace in traces {
      draw.engraved(optics.ray-path(trace.points), width: 0.0065, angle: 12deg, ink: draw.palette.pale-ink)
    }
    draw.label((-1.5, 1.35), [$L_1$])
    draw.label((1.35, 1.12), [$L_2$])
  })
  #draw.figure-caption([A finite beam traced through two ideal thin lenses.])
]

`import-ray-optics(json-data, beam-rays:, angle-rays:)` accepts the linear
`Beam`, `SingleRay`, `PointSource`, `IdealLens`, `Mirror`, `BeamSplitter`,
`Blocker`, `Aperture`, and `CropBox` objects exported by Ray Optics Simulation.
Unsupported curved and refractive-volume objects are ignored. The complete
`examples/kohler.typ` plate reads `assets/rayscenes/kohler.json`, computes every
ray, and only then converts traces with `ray-path` for engraving. `lens-path`
remains a visual outline helper and does not participate in the calculation.

`optics-illustration.import-scene` combines that import with crop-box boundaries,
tracing, and a centered drawing projection. Pass the result to
`optics-illustration.draw` inside an `illustration.canvas`; use
`optics-illustration.project` or `optics-illustration.label` for annotations in
the source scene's coordinate system. The renderer includes beams, lenses,
mirrors, beam splitters, blockers, apertures, rays, and the optical axis.

The mechanics namespace provides `rod`, `collar`, `joint`, and `lit-joint`
constructors. These return geometry primitives suitable for the same scene and
camera pipeline as all other solids. See `examples/governor-patent.typ` for a
complete assembly.

#align(center)[
  #draw.canvas(length: 0.65cm, {
    geo.render(
      mechanics.rod((0, 0, -1.4), (0, 0, 1.6), radius: 0.07, pattern: (geo.texture.striped)(10)),
      mechanics.collar((0, 0, 1.2), (0, 0, 1.5), radius: 0.22, stripes: 14),
      mechanics.rod((0, 0, 1.25), (-1.0, 0, 0.15)),
      mechanics.rod((0, 0, 1.25), (1.0, 0, 0.15)),
      mechanics.lit-joint((-1.08, 0, 0.05), radius: 0.34, seed: 21),
      mechanics.lit-joint((1.08, 0, 0.05), radius: 0.34, seed: 37),
      eye: (4.8, 6.2, 3.1),
      center: (0, 0, 0.15),
      width: 5.4,
      height: 4.4,
      step: 0.020,
      pen: (0.020, 0.0055, 24deg),
    )
  })
  #draw.figure-caption([Rods, collar, and lighting-aware joints in one assembly.])
]

= Document styles

Three show-rule templates provide restrained page furniture:

```typ
#show: premetadated.style.example.with(width: 16cm, height: 10cm)
```

```typ
#show: premetadated.style.plate.with(
  number: [Plate VII],
  title: [The Compound Microscope],
  subtitle: [longitudinal section and principal rays],
)
```

```typ
#show: premetadated.style.patent.with(
  title: [Improvement in Rotary Governors],
)
```

All accept page, paper, ink, and margin overrides. Keep reusable geometry in a
namespace module and page-specific layout in the document using the template.

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 5mm,
  align: center,
  [
    #box(width: 100%, height: 34mm, inset: 5mm, stroke: rgb("c7c1b8"))[
      #text(size: 7pt, weight: "bold")[Example]
      #v(4mm)
      #line(length: 80%, stroke: 0.4pt)
      #v(5mm)
      #align(center, text(size: 6.5pt, style: "italic")[compact neutral specimen])
    ]
  ],
  [
    #box(width: 100%, height: 34mm, inset: 5mm, fill: draw.palette.paper, stroke: rgb("c7b69d"))[
      #align(center)[
        #text(size: 5.5pt, tracking: 0.7pt)[PLATE VII]
        #linebreak()
        #text(size: 8pt)[Scientific Plate]
        #linebreak()
        #text(size: 5.5pt, style: "italic")[engraved figure and notes]
      ]
    ]
  ],
  [
    #box(width: 100%, height: 34mm, inset: 5mm, fill: rgb("f5eddf"), stroke: rgb("b9aa95"))[
      #grid(columns: (1fr, auto), text(size: 5pt, smallcaps[Patent Office]), text(size: 5pt)[No. 48,317])
      #v(2mm)
      #text(size: 8pt)[Mechanical Improvement]
      #v(2mm)
      #line(length: 100%, stroke: 0.4pt)
    ]
  ],
)
#align(center, text(size: 7.5pt, style: "italic")[Miniatures of the example, plate, and patent page vocabularies.])

= Examples and validation

The `examples/` directory contains focused stroke, geometry, shading, moon,
solid, knot, gesture, optics, and mechanical plates. Compile nested documents
with the repository as project root:

```sh
typst compile --root . examples/solids.typ examples/rendered/solids.pdf
typst compile --root . manual.typ manual.pdf
```

Contributors changing the Rust engine should run:

```sh
cargo fmt --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test --all-features
cargo build --release --target wasm32-unknown-unknown --features typst-plugin
```

= Credits and licensing

Premetadated directly depends on Cetz and Larnt; Larnt is a Rust rewrite of
Michael Fogleman's `ln`. MetaPost supplied the elliptical-pen model, while Fiziko
and vintage-latex inspired much of the visual vocabulary and specimen subject
matter. The eye and hand placeholders are Twemoji graphics.

See `ACKNOWLEDGMENTS.md` for detailed links, roles, and third-party licenses.
Premetadated itself is distributed under the Mozilla Public License 2.0.
