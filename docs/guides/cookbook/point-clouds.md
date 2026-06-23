---
title: Point clouds
parent: Cookbook
nav_order: 2
---

# Point clouds

`PointConverter.pointsToBody` turns a raw `[SIMD3<Float>]` into a point-only
`ViewportBody`. The body has empty `vertexData` / `indices` / `edges`; its
`vertices` carry the cloud points and its `primitiveKind` is `.point`, so
OCCTSwiftViewport dispatches to the point-sprite pipeline rather than
triangulating anything. That avoids the old sphere-compound workaround and lets
you render tens of thousands of points cleanly.

```swift
import simd
import OCCTSwiftTools

let points: [SIMD3<Float>] = (0..<10_000).map { _ in
    SIMD3<Float>(.random(in: -5...5), .random(in: -5...5), .random(in: -5...5))
}

guard let body = PointConverter.pointsToBody(
    points,
    id: "scan",
    pointRadius: 0.03
) else {
    fatalError("perPointColors length mismatch")
}
```

## Per-point colours

Pass `perPointColors` to colour each point individually. Its length **must**
match `points.count`, otherwise `pointsToBody` returns `nil`:

```swift
let colors: [SIMD4<Float>] = points.map { p in
    // colour by height
    let t = (p.y + 5) / 10
    return SIMD4<Float>(t, 0.3, 1 - t, 1)
}

let body = PointConverter.pointsToBody(
    points,
    id: "scan",
    pointRadius: 0.03,
    perPointColors: colors
)
```

When `perPointColors` is `nil`, every point uses the single `color` argument
(default: a soft amber, `SIMD4<Float>(1.0, 0.85, 0.2, 1.0)`).

## Clearing a point set

Empty input is valid and returns an empty body — handy for clearing a prior
point set while keeping the body id alive:

```swift
let cleared = PointConverter.pointsToBody([], id: "scan")
```

`pointRadius` is a world-space radius; the renderer projects it to screen pixels
and clamps the result to `[1, 64]` px (Apple's `[[point_size]]` upper bound).
