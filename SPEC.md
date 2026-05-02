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

## Public API (target shape)

The exact names should follow what's already in `OCCTSwiftViewport/Sources/OCCTSwiftTools/`. The headline surface is:

```swift
import OCCTSwift
import OCCTSwiftViewport

extension ViewportBody {
    /// Convert an `OCCTSwift.Shape` into a `ViewportBody` ready to render.
    /// - Parameters:
    ///   - shape: any B-Rep shape (solid, shell, face, wire, edge, vertex).
    ///   - linearDeflection: meshing tolerance for triangulation. Default 0.5.
    ///   - angularDeflection: meshing tolerance for curvature. Default 0.5.
    ///   - color: base material colour.
    public static func from(
        _ shape: Shape,
        linearDeflection: Double = 0.5,
        angularDeflection: Double = 0.5,
        color: SIMD3<Float> = SIMD3(0.7, 0.7, 0.7)
    ) -> ViewportBody?
}

/// One-shot file → body helpers.
public enum CADFile {
    public static func loadSTEP(at url: URL) throws -> [ViewportBody]
    public static func loadIGES(at url: URL) throws -> [ViewportBody]
    public static func loadSTL(at url: URL) throws -> ViewportBody
    public static func loadGLTF(at url: URL) throws -> [ViewportBody]
}
```

Plus whatever else lives in the current sub-product. **Do not invent new API in this repo.** First migrate, then add.

The `faceIndices` array on `ViewportBody` (per-triangle source-face index) is the linkage that OCCTSwiftAIS will read to map GPU pick results back to `TopoDS_Face` instances. Preserve it across the migration; it's load-bearing.

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
.package(url: "https://github.com/gsdali/OCCTSwiftViewport.git", from: "0.50.0"),
```

Pin to specific versions in `Package.resolved`; bump deliberately.

## Tests

At minimum:

- Unit: `Shape.box → ViewportBody → vertex / triangle counts` round-trip.
- Unit: `Shape.cylinder → ViewportBody`, verify `faceIndices` covers all source faces.
- Unit: STEP/IGES/STL/GLTF load returns at least one body for known-good fixtures.
- Integration: every public meshing tolerance combination terminates within reasonable time (no degenerate spinning).

Use small fixture files in `Tests/OCCTSwiftToolsTests/Fixtures/` (STEP samples from OCCTSwift's existing test data are fair game).

## Sequencing — first three releases

1. **v0.1.0** — Migrate the existing sub-product wholesale; everything builds and tests pass; same public API.
2. **v0.2.0** — Add convenience: `Shape.measure(linearTolerance:)` produces face-area / edge-length reports that flow into `ViewportBody.metadata` for consumption by OCCTSwiftAIS' dimension widget.
3. **v0.3.0** — STEP / IGES file-import progress callbacks (large assemblies block the main thread today).

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
