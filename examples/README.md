# Examples

Compile examples from the repository root so imports may resolve `../lib.typ`:

```sh
typst compile --root . examples/solids.typ examples/rendered/solids.pdf
```

| Source | Demonstrates |
| --- | --- |
| `strokes.typ` | Elliptical nibs, variable width, dashes, and closed paths |
| `geometry.typ` | Basic hidden-line Larnt scene |
| `shading-atlas.typ` | Lit hatching, broken fine lines, stippling, and pressure |
| `moon-phases.typ` | Lighting-aware sphere stippling |
| `solids.typ` | Ellipsoids, rounded boxes, and rounded convex polyhedra |
| `knots.typ` | Generic open and closed tubes following parametric paths |
| `gestures.typ` | Temporary Twemoji eye and hand SVGs with reusable vector anchors |
| `optics-plate.typ` | Compound microscope and ray construction |
| `kohler.typ` | Computed Köhler rays imported from a Ray Optics Simulation scene |
| `governor-patent.typ` | Reusable mechanical parts and multiple camera views |

Generated PDFs belong in `rendered/`; they are excluded from the Typst package.
