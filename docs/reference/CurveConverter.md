---
title: CurveConverter
parent: API Reference
---

# CurveConverter

Converts OCCTSwift curve objects to edge-only `ViewportBody` values. Each curve
is adaptively sampled into a single polyline stored on the body's `edges`; no
mesh is produced.

## Topics

- [curve2DToBody](#curveconvertercurve2dtobody) · [curve3DToBody](#curveconvertercurve3dtobody)

---

## `CurveConverter.curve2DToBody(...)`

Converts a `Curve2D` to an edge-only `ViewportBody`, projecting the curve onto
the XZ ground plane (Y = 0).

```swift
public static func curve2DToBody(
    _ curve: Curve2D,
    id: String,
    color: SIMD4<Float>
) -> ViewportBody
```

- **Parameters:**
  - `curve` — the 2D curve to sample (via its `drawAdaptive()`).
  - `id` — stable id for the body.
  - `color` — RGBA edge colour.
- **Returns:** a `ViewportBody` containing one edge polyline; its 2D points are mapped to `(x, 0, y)`.
- **Example:**
  ```swift
  let body = CurveConverter.curve2DToBody(
      profileCurve, id: "profile", color: SIMD4<Float>(0.9, 0.6, 0.2, 1)
  )
  ```

---

## `CurveConverter.curve3DToBody(...)`

Converts a `Curve3D` to an edge-only `ViewportBody` in full 3D space.

```swift
public static func curve3DToBody(
    _ curve: Curve3D,
    id: String,
    color: SIMD4<Float>
) -> ViewportBody
```

- **Parameters:**
  - `curve` — the 3D curve to sample (via its `drawAdaptive()`).
  - `id` — stable id for the body.
  - `color` — RGBA edge colour.
- **Returns:** a `ViewportBody` containing one edge polyline at the curve's 3D coordinates.
- **Example:**
  ```swift
  let body = CurveConverter.curve3DToBody(
      spline, id: "spline", color: SIMD4<Float>(0.2, 0.8, 1.0, 1)
  )
  ```

---
