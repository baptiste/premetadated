#import "illustration.typ": line-path

#let lens-path(x, height, bulge) = (
  ((x, -height), (x - bulge, -height * 0.52), (x - bulge, height * 0.52), (x, height)),
  ((x, height), (x + bulge, height * 0.52), (x + bulge, -height * 0.52), (x, -height)),
)

#let ray-path(points) = {
  let segments = ()
  for pair in points.windows(2) {
    segments.push(..line-path(pair.first(), pair.last()))
  }
  segments
}
