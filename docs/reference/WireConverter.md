---
title: WireConverter
parent: API Reference
---

# WireConverter

Converts an OCCTSwift `Wire` to an edge-only `ViewportBody` by extracting its
ordered edge polylines. If ordered-edge extraction yields nothing, it falls back
to wrapping the wire as a `Shape` and pulling edge polylines from there.

## Topics

- [wireToBody](#wireconverterwiretobody)
- Static defaults: [`defaultMaxPointsPerEdge`](#static-defaults) · [`defaultEdgeDeflection`](#static-defaults)

---

## `WireConverter.wireToBody(...)`

Extracts the ordered edges of a wire into per-edge polylines and packs them into
a single edge-only `ViewportBody`. Both the per-edge point cap and the
Shape-fallback deflection are tunable for dense curved wires.

```swift
public static func wireToBody(
    _ wire: Wire,
    id: String,
    color: SIMD4<Float>,
    maxPointsPerEdge: Int = defaultMaxPointsPerEdge,
    edgeDeflection: Double = defaultEdgeDeflection
) -> ViewportBody
```

- **Parameters:**
  - `wire` — the wire to convert.
  - `id` — stable id for the body.
  - `color` — RGBA edge colour.
  - `maxPointsPerEdge` — hard cap on points per edge polyline. Lower it to coarsen dense curved edges (e.g. helical threads). Defaults to `defaultMaxPointsPerEdge` (10000).
  - `edgeDeflection` — linear deflection used only by the Shape-based fallback path (when ordered-edge extraction yields nothing). Defaults to `defaultEdgeDeflection` (0.005).
- **Returns:** a `ViewportBody` whose `edges` hold one polyline per usable edge (edges with fewer than two points are skipped).
- **Example:**
  ```swift
  let body = WireConverter.wireToBody(
      wire, id: "outline", color: SIMD4<Float>(0.8, 0.8, 0.85, 1)
  )
  ```

---

## Static defaults

```swift
public static let defaultMaxPointsPerEdge: Int = 10000
public static let defaultEdgeDeflection: Double = 0.005
```

- `defaultMaxPointsPerEdge` — default per-edge point cap for ordered-edge wire extraction.
- `defaultEdgeDeflection` — default linear deflection for the Shape-fallback edge extraction.

---
