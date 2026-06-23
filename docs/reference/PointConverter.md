---
title: PointConverter
parent: API Reference
---

# PointConverter

Converts raw point clouds (`[SIMD3<Float>]`) to a point-only `ViewportBody`
drawn by OCCTSwiftViewport's point-sprite pipeline. Use it whenever you have
positions to display as points rather than meshed geometry — scan data, sampled
fields, or anything that would otherwise force a triangulated sphere compound.

## Topics

- [pointsToBody](#pointconverterpointstobody)

---

## `PointConverter.pointsToBody(...)`

Builds a `ViewportBody` whose `vertices` carry the input cloud and whose
`primitiveKind` is `.point`, so the renderer dispatches to the point-cloud
pipeline. `vertexData` / `indices` / `edges` are left empty — nothing is
triangulated.

```swift
public static func pointsToBody(
    _ points: [SIMD3<Float>],
    id: String,
    color: SIMD4<Float> = SIMD4<Float>(1.0, 0.85, 0.2, 1.0),
    pointRadius: Float = 0.05,
    perPointColors: [SIMD4<Float>]? = nil
) -> ViewportBody?
```

- **Parameters:**
  - `points` — point positions, in viewport-space coordinates. Empty is valid and yields an empty body (useful for clearing a prior point set without removing the body).
  - `id` — stable id for the body.
  - `color` — fallback colour (RGBA) applied to every point when `perPointColors` is `nil`. Defaults to a soft amber.
  - `pointRadius` — world-space radius for each point sprite. The renderer projects it to screen pixels and clamps to `[1, 64]` px.
  - `perPointColors` — optional per-point colours, stored on the body's `vertexColors`. Must match `points.count` when non-nil.
- **Returns:** the point `ViewportBody`, or `nil` when `perPointColors` is non-nil and its length does not equal `points.count`.
- **Example:**
  ```swift
  let pts: [SIMD3<Float>] = [
      SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0)
  ]
  let body = PointConverter.pointsToBody(pts, id: "cloud", pointRadius: 0.04)
  ```

---
