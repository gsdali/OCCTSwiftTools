---
title: SurfaceConverter
parent: API Reference
---

# SurfaceConverter

Converts an OCCTSwift `Surface` to a pair of edge-only `ViewportBody` values
showing its U and V isoparametric lines. Use it to visualize a surface as a
wireframe grid rather than a meshed patch.

## Topics

- [surfaceToGridBodies](#surfaceconvertersurfacetogridbodies)

---

## `SurfaceConverter.surfaceToGridBodies(...)`

Draws a surface's isoparametric grid as two edge-only bodies — one for the
U-direction lines, one for the V-direction lines — built from the surface's
`drawGrid(...)` output (50 points per line).

```swift
public static func surfaceToGridBodies(
    _ surface: Surface,
    idPrefix: String,
    offset: SIMD3<Double> = .zero,
    uColor: SIMD4<Float>,
    vColor: SIMD4<Float>,
    uLines: Int = 10,
    vLines: Int = 10
) -> [ViewportBody]
```

- **Parameters:**
  - `surface` — the surface to visualize.
  - `idPrefix` — id prefix; produces bodies `"\(idPrefix)-u"` and `"\(idPrefix)-v"`.
  - `offset` — 3D offset applied to every grid point. Defaults to `.zero`.
  - `uColor` — colour for the U-direction isoparametric lines.
  - `vColor` — colour for the V-direction isoparametric lines.
  - `uLines` — number of U-direction lines (default 10).
  - `vLines` — number of V-direction lines (default 10).
- **Returns:** an array of up to two `ViewportBody` values (`-u` then `-v`); a direction is omitted if it produced no usable polylines.
- **Example:**
  ```swift
  let bodies = SurfaceConverter.surfaceToGridBodies(
      surface,
      idPrefix: "patch",
      uColor: SIMD4<Float>(1, 0, 0, 1),
      vColor: SIMD4<Float>(0, 1, 0, 1),
      uLines: 12,
      vLines: 12
  )
  ```

---
