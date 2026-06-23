---
title: BodyUtilities
parent: API Reference
---

# BodyUtilities

Small helpers for creating and transforming `ViewportBody` values: a marker
sphere placed at a point, and translation of an existing body's vertices and
edges. Useful for annotation glyphs and quick repositioning without going back
through the kernel.

## Topics

- [makeMarkerSphere](#bodyutilitiesmakemarkersphere) · [offsetBody (returning)](#bodyutilitiesoffsetbody-returning) · [offsetBody (in place)](#bodyutilitiesoffsetbody-in-place)

---

## `BodyUtilities.makeMarkerSphere(...)`

Creates a small sphere marker `ViewportBody` centred at a given position, built
from `ViewportBody.sphere(...)` and then translated so its centre sits at
`position`.

```swift
public static func makeMarkerSphere(
    at position: SIMD3<Float>,
    radius: Float,
    id: String,
    color: SIMD4<Float>,
    segments: Int = 8,
    rings: Int = 4
) -> ViewportBody
```

- **Parameters:**
  - `position` — centre position of the marker sphere.
  - `radius` — sphere radius.
  - `id` — body identifier.
  - `color` — RGBA colour.
  - `segments` — number of longitudinal segments (default 8).
  - `rings` — number of latitudinal rings (default 4).
- **Returns:** a meshed sphere `ViewportBody` centred at `position`.
- **Example:**
  ```swift
  let marker = BodyUtilities.makeMarkerSphere(
      at: SIMD3<Float>(1, 2, 3),
      radius: 0.2,
      id: "pick",
      color: SIMD4<Float>(1, 0, 0, 1)
  )
  ```

---

## `BodyUtilities.offsetBody` (returning)

Returns a new `ViewportBody` with every vertex and edge point translated by
`(dx, dy, dz)`.

```swift
public static func offsetBody(
    _ body: ViewportBody,
    dx: Float,
    dy: Float = 0,
    dz: Float = 0
) -> ViewportBody
```

- **Parameters:**
  - `body` — the body to copy and translate.
  - `dx` — translation along X.
  - `dy` — translation along Y (default 0).
  - `dz` — translation along Z (default 0).
- **Returns:** a translated copy of `body`.
- **Example:**
  ```swift
  let moved = BodyUtilities.offsetBody(body, dx: 5, dz: -2)
  ```

---

## `BodyUtilities.offsetBody` (in place)

Translates a `ViewportBody`'s vertices and edges in place by `(dx, dy, dz)`.

```swift
public static func offsetBody(
    _ body: inout ViewportBody,
    dx: Float,
    dy: Float = 0,
    dz: Float = 0
)
```

- **Parameters:**
  - `body` — the body to mutate (passed `inout`).
  - `dx` / `dy` / `dz` — translation components (`dy` and `dz` default to 0).
- **Returns:** nothing; mutates `body` in place.
- **Example:**
  ```swift
  var body = someBody
  BodyUtilities.offsetBody(&body, dx: 5, dz: -2)
  ```

---
