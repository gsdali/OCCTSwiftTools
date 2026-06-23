---
title: Shape to ViewportBody
parent: Cookbook
nav_order: 1
---

# Shape to ViewportBody

The workhorse of the bridge layer is
`CADFileLoader.shapeToBodyAndMetadata`. Given an OCCTSwift `Shape`, it meshes
the solid, smooths normals, extracts the wireframe edge polylines, gathers the
source-shape vertices for picking, and returns a `(ViewportBody?,
CADBodyMetadata?)` pair. The `ViewportBody` is what the renderer draws; the
`CADBodyMetadata` carries the face indices, edge polylines, and vertex
positions that a selection layer (OCCTSwiftAIS) needs.

```swift
import OCCTSwift
import OCCTSwiftTools

let box = Shape.box(width: 10, height: 5, depth: 3)!

let (body, metadata) = CADFileLoader.shapeToBodyAndMetadata(
    box,
    id: "box",
    color: SIMD4<Float>(0.6, 0.6, 0.65, 1.0)
)

guard let body else {
    // nil means meshing failed AND no edge polylines could be extracted.
    fatalError("Shape could not be bridged to a body")
}

// `body` carries vertexData (interleaved position+normal), indices,
// wireframe `edges`, per-triangle faceIndices, and pick data.
// `metadata` carries faceIndices, edgePolylines, and source vertices.
```

## Mesh quality

By default `shapeToBodyAndMetadata` uses the high-quality CPU mesh preset
(`highQualityMeshParams`) for smooth curved surfaces without relying on GPU
tessellation. You can steer the mesh in three ways:

```swift
// Coarse mesh appropriate for already-tessellated STL data:
let (stlBody, _) = CADFileLoader.shapeToBodyAndMetadata(
    shape, id: "stl", color: color, stl: true
)

// A custom linear deflection (lower = smoother, more triangles):
let (fineBody, _) = CADFileLoader.shapeToBodyAndMetadata(
    shape, id: "fine", color: color, deflection: 0.02
)

// A coarser CPU mesh intended for GPU PN-triangle refinement:
let (pnBody, _) = CADFileLoader.shapeToBodyAndMetadata(
    shape, id: "pn", color: color, gpuTessellation: true
)
```

The two presets are exposed as static members so you can inspect or reuse them:
`CADFileLoader.highQualityMeshParams` and
`CADFileLoader.tessellationMeshParams`.

## Taming dense wireframe edges

Wireframe edge polylines are extracted independently of the triangle mesh, at
`CADFileLoader.defaultEdgeDeflection` (0.005) with a cap of
`CADFileLoader.defaultMaxPointsPerEdge` (1000) points per edge. For geometry
whose edges follow long fine curves — a helical thread, say — the default
produces an illegibly dense, slow wireframe. Coarsen it:

```swift
let (body, _) = CADFileLoader.shapeToBodyAndMetadata(
    threadedShape,
    id: "screw",
    color: color,
    edgeDeflection: 0.05,     // coarser edge sampling
    maxPointsPerEdge: 200     // hard cap per edge
)
```

## Per-face areas and per-edge lengths

Face-area iteration is O(faces), so measurements are off by default. Opt in when
you need them — they land on `metadata.measurements`:

```swift
let (body, metadata) = CADFileLoader.shapeToBodyAndMetadata(
    box, id: "box", color: color, includeMeasurements: true
)
let areas = metadata?.measurements   // per-face areas + per-edge lengths
```
