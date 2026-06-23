---
title: Curves, surfaces, and wires
parent: Cookbook
nav_order: 3
---

# Curves, surfaces, and wires

Three sibling converters turn the lower-dimensional OCCTSwift geometry types
into edge-only or grid `ViewportBody` values. None of them mesh a solid — they
produce wireframe polylines (or, for surfaces, isoparametric grids).

```swift
import simd
import OCCTSwift
import OCCTSwiftTools
```

## Curves

`CurveConverter` adaptively samples a curve and stores the result as a single
edge polyline. A `Curve2D` is projected onto the XZ ground plane (Y = 0); a
`Curve3D` keeps its full 3D coordinates.

```swift
let body3D = CurveConverter.curve3DToBody(
    curve3D,
    id: "spline",
    color: SIMD4<Float>(0.2, 0.8, 1.0, 1.0)
)

// 2D curve flattened onto the ground plane:
let body2D = CurveConverter.curve2DToBody(
    curve2D,
    id: "profile",
    color: SIMD4<Float>(0.9, 0.6, 0.2, 1.0)
)
```

## Surfaces

`SurfaceConverter.surfaceToGridBodies` draws a surface as its U and V
isoparametric lines, returning **two** bodies (one per direction) with ids
`"<idPrefix>-u"` and `"<idPrefix>-v"`. Tune the line counts and apply a 3D
offset if you want the grid nudged off the underlying solid.

```swift
let gridBodies = SurfaceConverter.surfaceToGridBodies(
    surface,
    idPrefix: "patch",
    uColor: SIMD4<Float>(1, 0, 0, 1),
    vColor: SIMD4<Float>(0, 1, 0, 1),
    uLines: 12,
    vLines: 12
)
// gridBodies == [ "patch-u", "patch-v" ]  (either may be omitted if empty)
```

## Wires

`WireConverter.wireToBody` extracts the ordered edges of a `Wire` as polylines.
If ordered-edge extraction yields nothing it falls back to wrapping the wire as
a `Shape` and pulling edge polylines from there. Both the per-edge point cap and
the fallback deflection are tunable for dense curved wires.

```swift
let body = WireConverter.wireToBody(
    wire,
    id: "outline",
    color: SIMD4<Float>(0.8, 0.8, 0.85, 1.0)
)

// Coarsen a dense curved wire (e.g. a helical thread profile):
let coarse = WireConverter.wireToBody(
    wire,
    id: "thread",
    color: color,
    maxPointsPerEdge: 500,
    edgeDeflection: 0.05
)
```

The defaults are exposed as `WireConverter.defaultMaxPointsPerEdge` (10000) and
`WireConverter.defaultEdgeDeflection` (0.005).
