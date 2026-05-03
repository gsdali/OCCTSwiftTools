# Changelog

Most recent first. Pre-1.0: free to break; deprecations documented here.

## v0.3.0 — 2026-05-03

Two more measurement primitives for OCCTSwiftAIS' dimension widget. The originally-planned v0.3.0 headline (STEP/IGES import progress callbacks) is **deferred to v0.4.0** — upstream OCCTSwift v0.167.0 doesn't wrap `Message_ProgressIndicator`, so we have nothing to bridge. Tracked in [OCCTSwift#98](https://github.com/gsdali/OCCTSwift/issues/98).

**New on `ShapeMeasurements`:**

- **`faceCentroids: [SIMD3<Double>]`** — surface center-of-mass for each face, parallel to `faceAreas`. Wraps `Face.surfaceInertia` (`BRepGProp_Sinert`).
- **`facePerimeters: [Double?]`** — outer-wire length for each face, parallel to `faceAreas`. `nil` when a face has no outer wire or wire length is unavailable. **Caveat**: this is the *outer* boundary length — for a face with internal holes, the inner-wire perimeters are excluded. Usually what dimension widgets want, but worth knowing.
- **`totalFacePerimeter: Double`** — convenience aggregate (skips nil entries).

**Behaviour:** `ShapeMeasurements.init` gains two new parameters with defaults `[]` (preserves source compatibility for any direct constructor calls). `Shape.measure(linearTolerance:)` populates all four arrays in one pass over `shape.faces()`.

**Dependencies:** unchanged (`OCCTSwift` ≥ `0.167.0`, `OCCTSwiftViewport` ≥ `0.51.0`).

## v0.2.0 — 2026-05-03

Convenience features pulled forward to unblock the OCCTSwiftAIS dimension widget. All three additions wrap upstream OCCTSwift APIs that already shipped in `0.167.0`; no version bump on the kernel floor.

**New:**

- **`ShapeMeasurements` + `Shape.measure(linearTolerance:)`** — per-face area (`Face.area`) and per-edge length (`Edge.length`) reports, indexed parallel to `shape.faces()` / `shape.edge(at: 0..<edgeCount)` so AIS can resolve a picked face/edge index directly to a scalar measurement. Convenience aggregates: `totalFaceArea`, `totalEdgeLength`.
- **`CADBodyMetadata.measurements: ShapeMeasurements?`** — populated when `shapeToBodyAndMetadata(...)` is called with `includeMeasurements: true`. Off by default — measurement iteration is O(faces+edges) and not free for large assemblies.
- **`CADFileFormat.iges`** (`.iges` / `.igs` extensions) — wraps `Shape.loadIGES(from:)` with `loadIGESRobust` fallback. IGES files commonly ship with gaps OCCT's basic importer can't close; the robust path applies sewing/healing.
- **`ExportFormat.gltf` and `.glb`** — wraps `Exporter.writeGLTF(shape:to:binary:deflection:)`. `.gltf` writes JSON + a sibling `.bin` buffer file; `.glb` writes a single binary container.

**Behaviour:**
- `CADBodyMetadata.init` gains a `measurements:` parameter with default `nil`. Existing call sites continue to work unchanged.
- `shapeToBodyAndMetadata(...)` gains `includeMeasurements: Bool = false`. Default behaviour is identical to v0.1.0.

**Deferred to v0.3.0:**
- Face centroid / mass properties / perimeter — upstream OCCTSwift hasn't wrapped `BRepGProp_Face` yet.
- STEP / IGES file-import progress callbacks.

**Dependencies:** unchanged (`OCCTSwift` ≥ `0.167.0`, `OCCTSwiftViewport` ≥ `0.51.0`).

## v0.1.0 — 2026-05-03

Initial release. Lifts the `OCCTSwiftTools` sub-product out of OCCTSwiftViewport into a standalone package so the Metal renderer (OCCTSwiftViewport) stays cleanly OCCT-free and the future OCCTSwiftAIS layer can depend on a stable bridge.

**Public API** (see [SPEC.md](../SPEC.md) "Public API (v0.1.0 — actual migrated surface)" for full signatures):

- `enum CADFileLoader` — `load(from:format:)`, `loadFromManifest(at:)`, `shapeToBodyAndMetadata(...)`, plus `highQualityMeshParams` / `tessellationMeshParams` presets.
- `enum CADFileFormat` — `.step`, `.stl`, `.obj`, `.brep`.
- `struct CADBodyMetadata`, `struct CADLoadResult`.
- `enum CurveConverter` — `curve2DToBody`, `curve3DToBody`.
- `enum SurfaceConverter` — `surfaceToGridBodies`.
- `enum WireConverter` — `wireToBody`.
- `enum BodyUtilities` — `makeMarkerSphere`, `offsetBody` (value + inout).
- `enum ExportManager` + `enum ExportFormat` — `.obj`, `.ply`, `.step`, `.brep`.
- `struct ScriptManifest` (Codable manifest format).

**Load-bearing contract:** `ViewportBody.faceIndices` (mirrored on `CADBodyMetadata.faceIndices`) is per-triangle source-face index data parallel to the triangle list. OCCTSwiftAIS will use it to map GPU pick results back to `TopoDS_Face` instances. Preserve bit-for-bit across future changes.

**Dependencies:**
- `OCCTSwift` ≥ `0.167.0`
- `OCCTSwiftViewport` ≥ `0.51.0` — the v0.51.0 floor is hard, not advisory: earlier viewport releases ship a target also named `OCCTSwiftTools`, which SPM rejects as a target-name collision across the package graph. Tracked in [OCCTSwiftViewport#22](https://github.com/gsdali/OCCTSwiftViewport/issues/22).

**Test invocation:** `OCCT_SERIAL=1 swift test --parallel --num-workers 1`. The env var + serial workers are required, not optional, due to a known NCollection container-overflow race in OCCT on arm64 macOS.

**Platform floor:** iOS 18 / macOS 15 / visionOS 1 / tvOS 18 — the higher of OCCTSwift's and OCCTSwiftViewport's floors.
