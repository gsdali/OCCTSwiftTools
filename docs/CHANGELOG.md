# Changelog

Most recent first. Pre-1.0: free to break; deprecations documented here.

## v0.6.0 — 2026-05-06

Closes [#12](https://github.com/gsdali/OCCTSwiftTools/issues/12). Splits file-I/O concerns into [OCCTSwiftIO](https://github.com/gsdali/OCCTSwiftIO) — a sibling package that depends on `OCCTSwift` only (no `OCCTSwiftViewport`). Headless consumers (Scripts, PadCAM CLI, batch pipelines, server-side workflows) can now load STEP / IGES / STL / OBJ / BREP files without dragging in the Metal renderer transitively.

**Source compatibility preserved.** `OCCTSwiftTools` adds `@_exported import OCCTSwiftIO` so every type that moved still resolves through `OCCTSwiftTools`'s surface — existing call sites (`OCCTSwiftTools.CADFileFormat`, `OCCTSwiftTools.ExportManager`, etc.) keep working unchanged.

**What moved to [OCCTSwiftIO v0.1.0](https://github.com/gsdali/OCCTSwiftIO/releases/tag/v0.1.0):**

- `enum CADFileFormat` — file-format enum.
- `enum ExportManager` + `enum ExportFormat` — OBJ / PLY / STEP / BREP / glTF / GLB writers.
- `struct ScriptManifest` — Codable harness manifest.
- `final class ImportProgressClosure` — closure-backed `OCCTSwift.ImportProgress` adapter.
- `struct CADBodyMetadata` — pure-data picking metadata. Stays Viewport-free; bridge consumes it.
- New: `enum ShapeLoader` — headless loader API. Returns `ShapeLoadResult { shapesWithColors, dimensions, geomTolerances, datums, manifest }`. No `ViewportBody`.

**What stays in `OCCTSwiftTools`:**

- `CADFileLoader.shapeToBodyAndMetadata(...)` — the bridge. Unchanged signature.
- `CADFileLoader.load(...)` — now a façade over `OCCTSwiftIO.ShapeLoader.load(...)` plus per-shape bridge. Returns `CADLoadResult` with `bodies: [ViewportBody]` as before.
- `CADFileLoader.loadFromManifest(...)` — same façade pattern.
- `CADLoadResult` (has `bodies: [ViewportBody]` — couldn't move).
- Mesh parameter presets (`highQualityMeshParams`, `tessellationMeshParams`).
- All Shape sub-type bridges: `CurveConverter`, `SurfaceConverter`, `WireConverter`, `BodyUtilities`.
- STL/IGES robust-loader fallback path: if the primary load + bridge fails (mesh nil), Tools re-loads via `Shape.loadSTLRobust` / `Shape.loadIGESRobust` and re-bridges. The fallback is bridge-aware so it lives here, not in IO.

**Consumer migration (optional):**

- Bridge users (AIS, CADKit, custom Metal viewers) — no change. `import OCCTSwiftTools` continues to work, and the `@_exported` re-export means even direct `OCCTSwiftTools.ExportManager` etc. references still resolve.
- Headless users (Scripts, PadCAM CLI, batch tools) — switch `import OCCTSwiftTools` to `import OCCTSwiftIO` and call `ShapeLoader.load(...)` directly to drop the transitive Viewport dep. `CADLoadResult` has no equivalent in IO; `ShapeLoadResult` is the headless analogue (`shapesWithColors`, no bodies).

**Dependencies bumped:**
- New: `OCCTSwiftIO` ≥ `0.1.0`.
- `OCCTSwift` ≥ `0.170.1` — unchanged.
- `OCCTSwiftViewport` ≥ `0.55.0` — unchanged.

**Tests:** down to **15 in 5 suites** (was 29 in 8) — `ExportManagerTests`, `ImportProgressTests`, `ScriptManifestTests` moved to OCCTSwiftIO. `CADFileLoaderTests`, `BodyUtilitiesTests`, `CurveConverterTests`, `SurfaceConverterTests`, `ShapeMeasurementsTests` stay.

## v0.5.1 — 2026-05-06

Closes [#13](https://github.com/gsdali/OCCTSwiftTools/issues/13). `ShapeMeasurements` and `Shape.measure(linearTolerance:)` were hoisted into the OCCTSwift kernel in [OCCTSwift v0.170.1](https://github.com/gsdali/OCCTSwift/releases/tag/v0.170.1) (PR [#163](https://github.com/gsdali/OCCTSwift/pull/163)). This release removes the duplicate copy that lived here.

**No public API change.** `ShapeMeasurements` and `shape.measure()` still resolve at every existing call site — they now come from `OCCTSwift` instead of `OCCTSwiftTools`. `CADFileLoader.shapeToBodyAndMetadata(includeMeasurements: true)` still populates `CADBodyMetadata.measurements` exactly as before; the field's type is now the kernel-side `ShapeMeasurements`, which is identical in shape and behaviour to the previous Tools-side type.

**What changed in the repo:**
- Deleted `Sources/OCCTSwiftTools/ShapeMeasurements.swift`.
- Trimmed `Tests/OCCTSwiftToolsTests/ShapeMeasurementsTests.swift` to the single Tools-specific case (`t_metadataIncludesMeasurementsWhenRequested`, which exercises `CADFileLoader.shapeToBodyAndMetadata`). The other 5 cases live in the OCCTSwift kernel test suite as of #163.

**Dependencies bumped:**
- `OCCTSwift` ≥ **0.170.1** *(was 0.168.0)* — required for the kernel-side `ShapeMeasurements` type. The xcframework binary is unchanged from v0.170.0, so SPM consumers don't re-download.
- `OCCTSwiftViewport` ≥ `0.55.0` — unchanged.

## v0.5.0 — 2026-05-03

**Behaviour change (pre-1.0).** Closes [#10](https://github.com/gsdali/OCCTSwiftTools/issues/10).

Converges `ViewportBody.vertices` / `vertexIndices` / `CADBodyMetadata.vertices` on the **source-shape convention** so AIS' `Selection.vertices` accessor (and any other consumer) can round-trip a picked `primitiveIndex` back to a `TopoDS_Vertex` via `shape.vertex(at: primitiveIndex)`. v0.4.1's polyline-endpoint convention rendered the same number of points for typical solids but in a different order, breaking that round-trip.

**What changed at runtime:**
- `body.vertices` is now `shape.vertices()` Float-converted (was: deduplicated polyline endpoints).
- `body.vertexIndices` is now the explicit identity array `[0, 1, …, n-1]` (was: empty, treated as identity by the renderer). Belt-and-braces against future renderer changes that drop the empty-as-identity interpretation.
- `CADBodyMetadata.vertices` aligns with `body.vertices` — single source of truth.

**No public API signature changes.** The `ViewportBody.init` and `CADBodyMetadata.init` shapes are unchanged; what's different is what populates them.

**AIS coordination:** AIS v0.6.1 currently overrides `body.vertices` and `body.vertexIndices` itself in `InteractiveContext.display(_:)` to fix the round-trip. Once consumers upgrade to OCCTSwiftTools v0.5.0, AIS can drop that override — both sides will be writing identical data, so the transition is non-breaking.

**Internal cleanup:** dropped the private `deduplicateVertices(from:)` helper (dead code post-convergence).

**Dependencies:** unchanged (`OCCTSwift` ≥ `0.168.0`, `OCCTSwiftViewport` ≥ `0.55.0`).

## v0.4.1 — 2026-05-03

Wires AIS edge + vertex GPU picking through. OCCTSwiftViewport v0.55.0 added the renderer-side edge/vertex pick pipelines ([viewport#24](https://github.com/gsdali/OCCTSwiftViewport/issues/24)), but their `body.edgeIndices` / `body.vertices` gates meant our bodies showed up as face-pickable only. Closes [#8](https://github.com/gsdali/OCCTSwiftTools/issues/8).

**Behaviour change in `CADFileLoader.shapeToBodyAndMetadata`:**

- **`ViewportBody.edgeIndices`** is now populated by flattening `metadata.edgePolylines` into per-segment indices. A polyline of N points contributes (N − 1) segments, each tagged with the source edge's index. Picked segment → `TopoDS_Edge`.
- **`ViewportBody.vertices`** is now populated with the deduplicated edge endpoints (same data as `metadata.vertices`).
- **`ViewportBody.vertexIndices`** stays empty — the renderer treats empty as identity (the pick result's `primitiveIndex` is the vertex index directly), so emitting a `[0, 1, 2, …]` array would be wasted bytes.

The data extraction (`extractEdgePolylines`, `deduplicateVertices`) was already running on every body, so this is a near-free wiring change. No public API surface change; existing call sites get the new pick fields populated with no opt-in required.

**Dependencies bumped:**
- `OCCTSwiftViewport` ≥ **0.55.0** *(was 0.51.0)* — required for the new `edgeIndices` / `vertices` / `vertexIndices` parameters on `ViewportBody.init`.
- `OCCTSwift` ≥ `0.168.0` — unchanged.

## v0.4.0 — 2026-05-03

STEP/IGES import progress + cancellation, finally. Upstream OCCTSwift v0.168.0 wrapped `Message_ProgressIndicator` (closing [OCCTSwift#98](https://github.com/gsdali/OCCTSwift/issues/98)) — this release plumbs that through the bridge.

**New:**

- **`CADFileLoader.load(from:format:progress:)`** — optional `progress: ImportProgress?` parameter (default `nil` — backwards compatible). Honored by `.step` and `.iges` formats only; STL/OBJ/BREP loaders are single-call upstream and don't surface progress.
- **`ImportProgressClosure`** — closure-backed `ImportProgress` adapter so callers don't need to write a one-shot subclass:

  ```swift
  let result = try await CADFileLoader.load(
      from: url, format: .step,
      progress: ImportProgressClosure(
          cancelCheck: { Task.isCancelled },
          progress: { fraction, step in
              Task { @MainActor in progressBar.setValue(fraction) }
          }
      )
  )
  ```

  `progress` callbacks fire on the importer's thread (a background thread when launched via `CADFileLoader.load`); UI updates must hop to the main actor explicitly.

**Cancellation:** Returning `true` from `progress.shouldCancel()` causes the import to throw `OCCTSwift.ImportError.cancelled` at the next OCCT progress boundary. Caller catches that to distinguish cancel from a real failure.

**IGES fallback note:** When `Shape.loadIGES` succeeds but `shapeToBodyAndMetadata` returns nil, the loader retries with `Shape.loadIGESRobust` (sewing/healing pass). Both passes use the same `progress` observer, so progress will sweep `0..1` twice in that scenario.

**Dependencies bumped:**
- `OCCTSwift` ≥ `0.168.0` *(was 0.167.0)* — required for `ImportProgress` protocol.
- `OCCTSwiftViewport` ≥ `0.51.0` — unchanged.

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
