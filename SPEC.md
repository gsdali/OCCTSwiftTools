# OCCTSwiftTools — implementation spec

This document is a brief for the next agent (Claude or human) picking up implementation. Read it end-to-end before writing code.

## What this repo is

The bridge product between two intentionally-decoupled siblings:

- **[OCCTSwift](https://github.com/gsdali/OCCTSwift)** — Swift wrapper around OpenCASCADE's modeling kernel. No Metal, no rendering. Currently shipping `v0.167.0` against OCCT 8.0.0-beta1 with macOS / iOS / visionOS / tvOS slices.
- **[OCCTSwiftViewport](https://github.com/gsdali/OCCTSwiftViewport)** — Pure-Metal viewport renderer. No OCCT dependency. Renders abstract `ViewportBody` objects.

`OCCTSwiftTools` is the only library that depends on **both**. It converts `OCCTSwift.Shape` (B-Rep topology + meshable surfaces) into `OCCTSwiftViewport.ViewportBody` (vertex / index / face-id buffers consumable by the Metal renderer), plus CAD file I/O wrappers that need both kernels working together.

It is being **promoted out of OCCTSwiftViewport's sub-product slot** into its own repo so:
1. OCCTSwiftViewport stays cleanly OCCT-free (it can build / test / version on its own).
2. `OCCTSwiftAIS` (sibling repo, sits one layer above this) can depend on a stable OCCTSwiftTools without dragging in viewport renderer changes.
3. CAD file I/O helpers (STEP/STL/IGES → renderable bodies in one call) get a clearer home.

## Architecture position

```
Application
   ↑
OCCTSwiftAIS         ← selection-from-topology, manipulators, dimensions
   ↑
OCCTSwiftTools       ← THIS REPO (bridge)
   ↑      ↑
OCCTSwift  OCCTSwiftViewport
(B-Rep)    (Metal)
```

OCCTSwiftTools depends on **both** OCCTSwift and OCCTSwiftViewport; OCCTSwiftAIS depends on OCCTSwiftTools (not the two siblings directly).

## Migration source

The current home of these types is `OCCTSwiftViewport/Sources/OCCTSwiftTools/` inside the viewport repo. **Read those files first** — they're the working starting point. Move them, don't rewrite.

```bash
# Inspect the current sub-product
ls ~/Projects/OCCTSwiftViewport/Sources/OCCTSwiftTools/
cat ~/Projects/OCCTSwiftViewport/Package.swift   # see how it was set up as a library product
```

The migration plan, in order:

1. Inventory every public type and method currently in `OCCTSwiftViewport/Sources/OCCTSwiftTools/`.
2. Move them to `OCCTSwiftTools/Sources/OCCTSwiftTools/` in this repo.
3. Move corresponding tests to `Tests/OCCTSwiftToolsTests/`.
4. Drop the `OCCTSwiftTools` library product + target from `OCCTSwiftViewport/Package.swift`. Cut a `v0.51.0` release of OCCTSwiftViewport that documents the move.
5. Tag this repo at `v0.1.0` once the move builds and tests pass.

The OCCTSwiftViewport repo continues to ship the `OCCTSwiftViewport` library; the `OCCTSwiftTools` library disappears from there in the same release that this repo's `v0.1.0` ships.

## Public API (v0.2.0)

```swift
import OCCTSwift
import OCCTSwiftViewport

// === Headline: file → renderable bodies ===

public enum CADFileFormat: String, Sendable {
    case step, stl, obj, brep, iges      // glTF still import-only via Document; export via ExportManager
    public init?(fileExtension ext: String)
}

public struct CADBodyMetadata: Sendable {
    public let faceIndices: [Int32]                                              // ⚑ load-bearing
    public let edgePolylines: [(edgeIndex: Int, points: [SIMD3<Float>])]
    public let vertices: [SIMD3<Float>]
    public let measurements: ShapeMeasurements?                                  // populated when includeMeasurements: true
}

// === Measurements (v0.2.0) — for OCCTSwiftAIS dimension widget ===

public struct ShapeMeasurements: Sendable {
    public let faceAreas: [Double]      // parallel to shape.faces()
    public let edgeLengths: [Double]    // parallel to shape.edge(at: 0..<edgeCount)
    public var totalFaceArea: Double { get }
    public var totalEdgeLength: Double { get }
}

extension Shape {
    public func measure(linearTolerance: Double = 1e-6) -> ShapeMeasurements
}

public struct CADLoadResult: @unchecked Sendable {
    public var bodies: [ViewportBody]
    public var metadata: [String: CADBodyMetadata]
    public var shapes: [Shape]
    public var dimensions: [DimensionInfo]
    public var geomTolerances: [GeomToleranceInfo]
    public var datums: [DatumInfo]
}

public enum CADFileLoader {
    public static func load(from url: URL, format: CADFileFormat) async throws -> CADLoadResult
    public static func loadFromManifest(at url: URL) throws -> CADLoadResult
    public static func shapeToBodyAndMetadata(
        _ shape: Shape, id: String, color: SIMD4<Float>,
        stl: Bool = false, deflection: Double? = nil, gpuTessellation: Bool = false,
        includeMeasurements: Bool = false                                        // NEW v0.2.0
    ) -> (ViewportBody?, CADBodyMetadata?)
    public static let highQualityMeshParams: MeshParameters
    public static let tessellationMeshParams: MeshParameters
}

// === Bridge converters (Shape sub-types → ViewportBody) ===

public enum CurveConverter {
    public static func curve2DToBody(_ curve: Curve2D, id: String, color: SIMD4<Float>) -> ViewportBody
    public static func curve3DToBody(_ curve: Curve3D, id: String, color: SIMD4<Float>) -> ViewportBody
}

public enum SurfaceConverter {
    public static func surfaceToGridBodies(
        _ surface: Surface, idPrefix: String,
        offset: SIMD3<Double> = .zero,
        uColor: SIMD4<Float>, vColor: SIMD4<Float>,
        uLines: Int = 10, vLines: Int = 10
    ) -> [ViewportBody]
}

public enum WireConverter {
    public static func wireToBody(_ wire: Wire, id: String, color: SIMD4<Float>) -> ViewportBody
}

// === Pure-viewport utilities (no OCCT dep) ===

public enum BodyUtilities {
    public static func makeMarkerSphere(at: SIMD3<Float>, radius: Float, id: String,
                                        color: SIMD4<Float>, segments: Int = 8, rings: Int = 4) -> ViewportBody
    public static func offsetBody(_ body: ViewportBody, dx: Float, dy: Float = 0, dz: Float = 0) -> ViewportBody
    public static func offsetBody(_ body: inout ViewportBody, dx: Float, dy: Float = 0, dz: Float = 0)
}

// === Export (OCCT-only) ===

public enum ExportFormat: String, CaseIterable, Sendable {
    case obj, ply, step, brep, gltf, glb     // .gltf = JSON + sibling .bin; .glb = single binary container
}

public enum ExportManager {
    public static func export(shapes: [Shape], format: ExportFormat,
                              to url: URL, deflection: Double = 0.1) async throws
}

// === Manifest model (Codable, no OCCT/viewport dep) ===

public struct ScriptManifest: Codable, Sendable {
    public let version: Int
    public let timestamp: Date
    public let description: String?
    public let bodies: [BodyDescriptor]
    public let metadata: ManifestMetadata?
    public struct BodyDescriptor: Codable, Sendable { /* id, file, format, name, roughness, metallic, color */ }
    public struct ManifestMetadata: Codable, Sendable { /* name, revision, dates, source, tags, notes */ }
}
```

### Load-bearing contract: `faceIndices`

`ViewportBody.faceIndices` (and its mirror `CADBodyMetadata.faceIndices`) is a per-triangle source-face index, parallel to the triangle list (`indices.count / 3 == faceIndices.count`). OCCTSwiftAIS will read this to map GPU pick results back to `TopoDS_Face` instances. **Preserve it bit-for-bit across any future change** — semantic drift here breaks pick-to-topology mapping in the layer above.

## Repo conventions

Match OCCTSwift's conventions exactly. Cribbed verbatim from that repo's CLAUDE.md and memory:

- **License**: LGPL 2.1 (same as OCCT itself, with the OCCT_LGPL_EXCEPTION). Copy from OCCTSwift.
- **swift-tools-version**: 6.1. Language mode: `.v6`.
- **Platforms**: `.iOS(.v15)`, `.macOS(.v12)`, `.visionOS(.v1)`, `.tvOS(.v15)`. (OCCTSwiftViewport requires iOS 18 / macOS 15 — when it does, OCCTSwiftTools' platform floor is the higher of the two: `.iOS(.v18)`, `.macOS(.v15)`. Use the higher pair.)
- **Tests**: Swift Testing (`@Suite` / `@Test` / `#expect`). Never `#expect(x != nil); #expect(x!.isValid)` — Swift Testing does not short-circuit. Always `if let x { #expect(x.isValid) }`.
- **Test naming**: `@Test func` names must NOT shadow API method names used inside the test body (test runner gets confused). Prefix with `t_` or use descriptive English.
- **OCCT race**: when running tests, set `OCCT_SERIAL=1 swift test --parallel --num-workers 1`. There's a known NCollection container-overflow race in OCCT on arm64 macOS that segfaults parallel runs.
- **Versioning**: tiny additive features = patch bump (x.y.z+1), not minor. Minor bumps for new public API surface.
- **Release pattern**: every shipped version commits + pushes + tags + creates a GitHub release with notes. Release notes go in `docs/CHANGELOG.md` (most recent first, "Current" header pinned to the new version).
- **Pre-1.0**: free to break. Document deprecations in CHANGELOG.
- **README**: shields.io SPI badges (Swift versions / platforms / license), install snippet pinning to the most recent semver, "Supported Platforms" table, link to ecosystem repos.
- **CODE_OF_CONDUCT.md**: short pointer to Contributor Covenant 2.1, **never** inline the full text — Anthropic's content filter blocks it.
- **`.spi.yml`**: SPI build matrix for Swift 6.0 / 6.1 / 6.2 / 6.3 + iOS, with `documentation_targets: [OCCTSwiftTools]`. Submission to swiftpackageindex.com is gated on v1.0.0.

## Distribution

This repo does **not** ship a binary. It depends on OCCTSwift (which ships `OCCT.xcframework` as a release asset) and OCCTSwiftViewport (pure Swift). SPM resolves both transitively.

```swift
// Package.swift dependencies
.package(url: "https://github.com/gsdali/OCCTSwift.git",         from: "0.167.0"),
.package(url: "https://github.com/gsdali/OCCTSwiftViewport.git", from: "0.51.0"),
```

Pin to specific versions in `Package.resolved`; bump deliberately.

## Tests

OCCTSwift ships no fixture files (its test geometry is generated at runtime), and STEP/BREP/STL samples in this repo would bloat the package. So tests **generate geometry at runtime** via `Shape.box`, `Shape.cylinder`, etc. Temp files for export round-trips go to `/tmp` — never under `Tests/`.

At minimum:

- `CADFileLoaderTests` — `Shape.box → shapeToBodyAndMetadata → ViewportBody` round-trip; verify `vertexData.count % 6 == 0`, `indices.count % 3 == 0`, `faceIndices.count == indices.count / 3`. Cylinder body's `metadata.faceIndices` covers all 3 source faces (top, bottom, lateral).
- `BodyUtilitiesTests` — `offsetBody` shifts every vertex by the given delta; `makeMarkerSphere` produces the expected vertex count for default segments/rings.
- `CurveConverterTests` — 2D curve maps to Y=0 plane; 3D curve preserves Z.
- `SurfaceConverterTests` — emits 1–2 bodies with `-u`/`-v` ID suffixes; edge counts match `uLines`/`vLines`.
- `ExportManagerTests` — round-trip box export to OBJ/STEP/BREP/glTF/GLB into `/tmp`; assert files exist and are non-empty.
- `ScriptManifestTests` — Codable round-trip including `colorArray` ↔ `color: SIMD4<Float>` mapping.
- `ShapeMeasurementsTests` — box totals match analytical surface area (62 mm² for 2×3×5) and edge length (40 mm); `includeMeasurements: true` populates `CADBodyMetadata.measurements`.

## Sequencing

1. **v0.1.0** *(shipped)* — Wholesale migration out of OCCTSwiftViewport's sub-product slot. See [docs/CHANGELOG.md](docs/CHANGELOG.md).
2. **v0.2.0** *(shipped)* — `Shape.measure(linearTolerance:)` + `ShapeMeasurements` for AIS dimension widgets; IGES loader (`.iges` / `.igs` via `Shape.loadIGES` with `loadIGESRobust` fallback); glTF/GLB export (`.gltf` JSON+`.bin`, `.glb` single-binary container).
3. **v0.3.0** *(planned)* — STEP / IGES file-import progress callbacks (large assemblies block the main thread today). Possibly: face centroid + perimeter convenience on `ShapeMeasurements` (deferred from v0.2.0 — upstream OCCTSwift hasn't wrapped `BRepGProp_Face` mass properties yet).

After v0.3 the surface is essentially stable; sit on v0.x until OCCTSwiftAIS lands and exercises it.

## Ecosystem context to read before coding

- `~/Projects/OCCTSwift/CLAUDE.md` — project conventions for the kernel
- `~/Projects/OCCTSwift/docs/visualization-research.md` — why this layer cake exists
- `~/Projects/OCCTSwift/docs/platform-expansion.md` — platform reasoning
- `~/.claude/projects/-Users-elb-Projects-OCCTSwift/memory/MEMORY.md` — saved conventions / feedback (LGPL, /tmp staging, Swift Testing patterns, content-filter CoC, SPM packaging)

## What is explicitly out of scope

- Selection / picking semantics (that's OCCTSwiftAIS).
- Manipulator widgets (OCCTSwiftAIS).
- Dimension annotations (OCCTSwiftAIS).
- A full headless ray-tracing renderer (use CADRays separately).
- Linux / Windows / Android — see `OCCTSwift/docs/platform-expansion.md`.
- Apple Watch (memory-constrained).
