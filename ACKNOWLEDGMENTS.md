# Acknowledgments

Premetadated combines original Typst and Rust code with open-source libraries
and ideas from several scientific-illustration projects. This document records
which relationships are dependencies, adaptations, or inspiration.

## Rendering foundations

- [Cetz](https://github.com/cetz-package/cetz) supplies the Typst canvas and
  vector drawing layer. Premetadated emits Cetz paths and filled nib envelopes.
- [Larnt](https://github.com/HellOwhatAs/larnt), licensed under MIT, is a direct
  Rust dependency for camera projection, visibility testing, and hidden-line
  removal. Premetadated adds its own shapes, lighting marks, and Typst protocol
  around that renderer.
- Larnt is itself a Rust rewrite of Michael Fogleman's
  [`ln`](https://github.com/fogleman/ln), also MIT licensed. Its path-based 3D
  line-art model is therefore part of this project's technical lineage.
- [`i_overlay`](https://github.com/iShape-Rust/iOverlay) performs robust cleanup
  of self-intersecting pen envelopes, and
  [`parry3d`](https://github.com/dimforge/parry) supplies convex-hull geometry.

## Pen and illustration ideas

- [MetaPost](https://tug.org/metapost.html), created by John D. Hobby, is the
  conceptual source for the elliptical-pen stroke model. Premetadated uses a
  flatten-and-clean implementation rather than MetaPost's analytic envelope
  algorithm.
- Sergey Slyusarev's [Fiziko](https://github.com/jemmybutton/fiziko), licensed
  under GPL-3.0, inspired the variable-width line work, shaded scientific
  solids, tubes, knots, optics, mechanics, and compact reusable illustration
  vocabulary. Its article
  [“Various things in MetaPost”](https://habr.com/en/articles/454376/) directly
  motivated Premetadated's variable-radius tube profiles.
- Foad S. Farimani's
  [vintage-latex](https://github.com/Foadsf/vintage-latex), licensed under
  CC BY-SA 4.0, inspired the historical plate styling and several specimen
  subjects used to exercise the API.

Fiziko and vintage-latex source code is not vendored in this repository. Their
ideas and visual examples were reimplemented independently for Typst and the
Rust/WASM plugin; the links above are provided both as credit and as excellent
references for the broader design tradition.

The standalone ray tracer and JSON interchange in `optics.typ` were informed by
[Ray Optics Simulation](https://github.com/ricktu288/ray-optics), licensed under
Apache-2.0. Premetadated does not vendor its implementation; it independently
implements the thin-lens, reflection, stopping, and branching equations while
accepting a documented subset of its exported scene object schema.

## Bundled graphics

The temporary hand SVG placeholders and retained eye reference asset are
unmodified [Twemoji](https://github.com/twitter/twemoji) graphics, copyright
2019 Twitter, Inc. and other contributors, licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Exact asset details
are recorded in [`assets/twemoji/ATTRIBUTION.md`](assets/twemoji/ATTRIBUTION.md).

## Protocol and ecosystem

The bundled plugin uses
[`wasm-minimal-protocol`](https://github.com/astrale-sharp/wasm-minimal-protocol)
to expose Rust functions to Typst and `bincode` for the compact wire format.
Premetadated is distributed under the Mozilla Public License 2.0; each upstream
component remains under its own license.