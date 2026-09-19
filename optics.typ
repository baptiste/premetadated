// Standalone two-dimensional geometric optics. This module deliberately has no
// drawing imports: traces are point arrays that any renderer can consume.

#let _epsilon = 1e-6

#let _add(a, b) = (a.at(0) + b.at(0), a.at(1) + b.at(1))
#let _sub(a, b) = (a.at(0) - b.at(0), a.at(1) - b.at(1))
#let _scale(vector, factor) = (vector.at(0) * factor, vector.at(1) * factor)
#let _dot(a, b) = a.at(0) * b.at(0) + a.at(1) * b.at(1)
#let _cross(a, b) = a.at(0) * b.at(1) - a.at(1) * b.at(0)
#let _length(vector) = calc.sqrt(_dot(vector, vector))
#let _unit(vector) = {
  let length = _length(vector)
  assert(length > _epsilon, message: "Optical directions and elements must have nonzero length")
  _scale(vector, 1 / length)
}
#let _rotate(vector, angle) = (
  vector.at(0) * calc.cos(angle) - vector.at(1) * calc.sin(angle),
  vector.at(0) * calc.sin(angle) + vector.at(1) * calc.cos(angle),
)
#let _lerp(a, b, amount) = _add(a, _scale(_sub(b, a), amount))

#let ray(origin, direction, brightness: 1, wavelength: none) = (
  origin: origin,
  direction: _unit(direction),
  brightness: brightness,
  wavelength: wavelength,
)

#let point-source(origin, start-angle: -15deg, end-angle: 15deg, count: 9, brightness: 1, wavelength: none) = {
  assert(count >= 1, message: "A point source needs at least one ray")
  range(count).map(index => {
    let amount = if count == 1 { 0.5 } else { index / (count - 1) }
    let angle = start-angle + amount * (end-angle - start-angle)
    ray(origin, (calc.cos(angle), calc.sin(angle)), brightness: brightness / count, wavelength: wavelength)
  })
}

#let beam-source(p1, p2, direction: none, count: 11, spread: 0deg, angle-count: 1, brightness: 1, wavelength: none) = {
  assert(count >= 1 and angle-count >= 1, message: "A beam needs at least one spatial and angular sample")
  let edge = _sub(p2, p1)
  let central = if direction == none { _unit((edge.at(1), -edge.at(0))) } else { _unit(direction) }
  let rays = ()
  for spatial-index in range(count) {
    let spatial = if count == 1 { 0.5 } else { spatial-index / (count - 1) }
    for angle-index in range(angle-count) {
      let angular = if angle-count == 1 { 0.5 } else { angle-index / (angle-count - 1) }
      let angle = -spread / 2 + angular * spread
      rays.push(ray(
        _lerp(p1, p2, spatial),
        _rotate(central, angle),
        brightness: brightness / (count * angle-count),
        wavelength: wavelength,
      ))
    }
  }
  rays
}

#let ideal-lens(p1, p2, focal-length, transmission: 1) = (
  type: "ideal-lens",
  p1: p1,
  p2: p2,
  focal-length: focal-length,
  transmission: transmission,
)

#let mirror(p1, p2, reflectivity: 1) = (
  type: "mirror",
  p1: p1,
  p2: p2,
  reflectivity: reflectivity,
)

#let blocker(p1, p2) = (type: "blocker", p1: p1, p2: p2)

#let aperture(p1, p2, opening-p1, opening-p2) = (
  type: "aperture",
  p1: p1,
  p2: p2,
  opening-p1: opening-p1,
  opening-p2: opening-p2,
)

#let beam-splitter(p1, p2, transmission: 0.5, reflection: 0.5) = (
  type: "beam-splitter",
  p1: p1,
  p2: p2,
  transmission: transmission,
  reflection: reflection,
)

#let _segments(element) = if element.type == "aperture" {
  (
    (element.p1, element.opening-p1),
    (element.opening-p2, element.p2),
  )
} else {
  ((element.p1, element.p2),)
}

#let _intersection(origin, direction, p1, p2) = {
  let edge = _sub(p2, p1)
  let denominator = _cross(direction, edge)
  if calc.abs(denominator) <= _epsilon {
    none
  } else {
    let offset = _sub(p1, origin)
    let distance = _cross(offset, edge) / denominator
    let position = _cross(offset, direction) / denominator
    if distance > _epsilon and position >= -_epsilon and position <= 1 + _epsilon {
      (distance: distance, point: _add(origin, _scale(direction, distance)))
    } else {
      none
    }
  }
}

#let _nearest-hit(origin, direction, elements) = {
  let nearest = none
  for (element-index, element) in elements.enumerate() {
    for segment in _segments(element) {
      let hit = _intersection(origin, direction, segment.first(), segment.last())
      if hit != none and (nearest == none or hit.distance < nearest.distance) {
        nearest = hit + (element: element, element-index: element-index, segment: segment)
      }
    }
  }
  nearest
}

#let _reflected(direction, segment) = {
  let tangent = _unit(_sub(segment.last(), segment.first()))
  let normal = (-tangent.at(1), tangent.at(0))
  _unit(_sub(direction, _scale(normal, 2 * _dot(direction, normal))))
}

#let _through-lens(direction, point, lens) = {
  let tangent = _unit(_sub(lens.p2, lens.p1))
  let normal = (tangent.at(1), -tangent.at(0))
  let forward = if _dot(direction, normal) < 0 { _scale(normal, -1) } else { normal }
  let axial = _dot(direction, forward)
  if calc.abs(axial) <= _epsilon {
    direction
  } else {
    let center = _lerp(lens.p1, lens.p2, 0.5)
    let height = _dot(_sub(point, center), tangent)
    let incoming-slope = _dot(direction, tangent) / axial
    let outgoing-slope = incoming-slope - height / lens.focal-length
    _unit(_add(forward, _scale(tangent, outgoing-slope)))
  }
}

#let _outgoing(ray-state, hit) = {
  let element = hit.element
  if element.type == "blocker" or element.type == "aperture" {
    ()
  } else if element.type == "ideal-lens" {
    ((
      direction: _through-lens(ray-state.direction, hit.point, element),
      brightness: ray-state.brightness * element.transmission,
    ),)
  } else if element.type == "mirror" {
    ((
      direction: _reflected(ray-state.direction, hit.segment),
      brightness: ray-state.brightness * element.reflectivity,
    ),)
  } else if element.type == "beam-splitter" {
    (
      (direction: ray-state.direction, brightness: ray-state.brightness * element.transmission),
      (direction: _reflected(ray-state.direction, hit.segment), brightness: ray-state.brightness * element.reflection),
    ).filter(branch => branch.brightness > 0)
  } else {
    panic("Unknown optical element type: " + element.type)
  }
}

#let trace-ray(input-ray, elements, max-distance: 1000, max-interactions: 16, min-brightness: 1e-4, max-branches: 64) = {
  let active = ((
    origin: input-ray.origin,
    direction: input-ray.direction,
    brightness: input-ray.brightness,
    wavelength: input-ray.wavelength,
    points: (input-ray.origin,),
    interactions: 0,
  ),)
  let traces = ()

  while active.len() > 0 and traces.len() < max-branches {
    let state = active.first()
    active = active.slice(1)
    let hit = _nearest-hit(state.origin, state.direction, elements)
    if hit == none or state.interactions >= max-interactions {
      traces.push(state + (
        points: state.points + (_add(state.origin, _scale(state.direction, max-distance)),),
        terminated-by: if hit == none { "distance" } else { "interaction-limit" },
      ))
    } else {
      let points = state.points + (hit.point,)
      let branches = _outgoing(state, hit)
      if branches.len() == 0 {
        traces.push(state + (points: points, terminated-by: hit.element.type))
      } else {
        for branch in branches {
          if branch.brightness >= min-brightness {
            active.push((
              origin: _add(hit.point, _scale(branch.direction, _epsilon * 10)),
              direction: branch.direction,
              brightness: branch.brightness,
              wavelength: state.wavelength,
              points: points,
              interactions: state.interactions + 1,
            ))
          }
        }
      }
    }
  }
  traces + active.map(state => state + (points: state.points, terminated-by: "branch-limit"))
}

#let trace-scene(scene, max-distance: 1000, max-interactions: 16, min-brightness: 1e-4, max-branches: 64) = scene.rays.map(input-ray => trace-ray(
  input-ray,
  scene.elements,
  max-distance: max-distance,
  max-interactions: max-interactions,
  min-brightness: min-brightness,
  max-branches: max-branches,
)).flatten()

#let _json-point(point) = (point.x, point.y)

#let import-ray-optics(data, beam-rays: 13, angle-rays: 3) = {
  let rays = ()
  let elements = ()
  let bounds = none

  for object in data.objs {
    let kind = object.type
    if kind == "Beam" {
      rays += beam-source(
        _json-point(object.p1),
        _json-point(object.p2),
        count: beam-rays,
        spread: object.at("emisAngle", default: 0) * 1deg,
        angle-count: angle-rays,
        brightness: object.at("brightness", default: 1),
        wavelength: object.at("wavelength", default: none),
      )
    } else if kind == "SingleRay" {
      rays.push(ray(
        _json-point(object.p1),
        _sub(_json-point(object.p2), _json-point(object.p1)),
        brightness: object.at("brightness", default: 1),
        wavelength: object.at("wavelength", default: none),
      ))
    } else if kind == "PointSource" {
      let count = beam-rays * angle-rays
      rays += point-source(
        (object.x, object.y),
        start-angle: 0deg,
        end-angle: (1 - 1 / count) * 360deg,
        count: count,
        brightness: object.at("brightness", default: 1),
        wavelength: object.at("wavelength", default: none),
      )
    } else if kind == "IdealLens" {
      elements.push(ideal-lens(_json-point(object.p1), _json-point(object.p2), object.focalLength))
    } else if kind == "Mirror" {
      elements.push(mirror(_json-point(object.p1), _json-point(object.p2)))
    } else if kind == "BeamSplitter" {
      elements.push(beam-splitter(
        _json-point(object.p1),
        _json-point(object.p2),
        transmission: object.at("transRatio", default: 0.5),
        reflection: 1 - object.at("transRatio", default: 0.5),
      ))
    } else if kind == "Blocker" {
      elements.push(blocker(_json-point(object.p1), _json-point(object.p2)))
    } else if kind == "Aperture" {
      elements.push(aperture(
        _json-point(object.p1),
        _json-point(object.p2),
        _json-point(object.p3),
        _json-point(object.p4),
      ))
    } else if kind == "CropBox" {
      bounds = (p1: _json-point(object.p1), p2: _json-point(object.p4))
    }
  }

  (rays: rays, elements: elements, bounds: bounds, source: data)
}

#let lens-path(x, height, bulge) = (
  ((x, -height), (x - bulge, -height * 0.52), (x - bulge, height * 0.52), (x, height)),
  ((x, height), (x + bulge, height * 0.52), (x + bulge, -height * 0.52), (x, -height)),
)

#let ray-path(points) = {
  let segments = ()
  for pair in points.windows(2) {
    segments.push((pair.first(), pair.first(), pair.last(), pair.last()))
  }
  segments
}
