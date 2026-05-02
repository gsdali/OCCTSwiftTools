# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo state: bootstrap / migration-in-progress

`Sources/OCCTSwiftTools/` and `Tests/OCCTSwiftToolsTests/` are **empty** (`.gitkeep` only). Implementation has not landed yet — it is being lifted out of [OCCTSwiftViewport's sub-product slot](https://github.com/gsdali/OCCTSwiftViewport) into this standalone repo per [SPEC.md](SPEC.md).

**Before writing any code, read the source you are migrating from:**

```bash
ls ~/Projects/OCCTSwiftViewport/Sources/OCCTSwiftTools/
# BodyUtilities.swift  CADFileLoader.swift  CurveConverter.swift
# ExportManager.swift  ScriptManifest.swift  SurfaceConverter.swift
# WireConverter.swift
```

**Move, don't rewrite.** Public API names should match what already exists there. The headline shape is `ViewportBody.from(_ shape: Shape, …)` plus a `CADFile` enum with `loadSTEP/loadIGES/loadSTL/loadGLTF`. Do not invent new API in this repo before the migration is complete (v0.1.0 = wholesale migration; v0.2.0 = first additive features — see SPEC.md "Sequencing").

The migration also requires a coordinated change in OCCTSwiftViewport: drop its `OCCTSwiftTools` library product/target and cut `v0.51.0` of that repo in the same release that ships `v0.1.0` here.

## Architectural position (load-bearing context)

```
OCCTSwiftAIS         (selection / manipulators / dimensions — sibling repo, depends on us)
       ↑
OCCTSwiftTools       ← this repo: the only library that depends on BOTH siblings below
       ↑      ↑
OCCTSwift   OCCTSwiftViewport
(B-Rep)     (Metal renderer, intentionally OCCT-free)
```

The whole point of extracting this repo is to keep OCCTSwiftViewport cleanly OCCT-free so the two kernels stay decoupled. Do not add OCCT-aware code to OCCTSwiftViewport, and do not add Metal/rendering code to OCCTSwift — both of those go here.

**`ViewportBody.faceIndices` (per-triangle source-face index) is load-bearing.** OCCTSwiftAIS reads it to map GPU pick results back to `TopoDS_Face` instances. Preserve it across the migration; do not change its semantics without a coordinated change in OCCTSwiftAIS.

## Build & test

```bash
swift build
OCCT_SERIAL=1 swift test --parallel --num-workers 1   # MUST run serially
swift test --filter OCCTSwiftToolsTests.SuiteName/testName   # single test
```

`OCCT_SERIAL=1` + serial workers is **required**, not optional: there is a known NCollection container-overflow race in OCCT on arm64 macOS that segfaults parallel test runs. This is inherited from OCCTSwift; do not "fix" it by re-enabling parallelism.

Dependencies resolve transitively — OCCTSwift ships `OCCT.xcframework` as a release asset, OCCTSwiftViewport is pure Swift. No binary lives in this repo.

## Platform floor

`Package.swift` pins `.iOS(.v18)`, `.macOS(.v15)`, `.visionOS(.v1)`, `.tvOS(.v18)`. This is the **max** of OCCTSwift's floor (12.0/15.0) and OCCTSwiftViewport's (15.0/18.0) — not arbitrary. If either sibling raises its floor, raise ours to match; never lower below either sibling.

## Conventions cribbed from OCCTSwift

These are the non-obvious ones — match the kernel repo exactly:

- **License**: LGPL 2.1 with `OCCT_LGPL_EXCEPTION` (matches OCCT itself). Already in `LICENSE`.
- **Swift**: tools-version 6.1, language mode `.v6`.
- **Tests**: Swift Testing (`@Suite` / `@Test` / `#expect`). Swift Testing **does not short-circuit** — never write `#expect(x != nil); #expect(x!.isValid)`. Always `if let x { #expect(x.isValid) }`.
- **Test names must not shadow API method names** used inside the test body — the test runner gets confused. Prefix `t_` or use descriptive English.
- **CODE_OF_CONDUCT.md**: short pointer to Contributor Covenant 2.1 only. **Never inline the full Covenant text** — Anthropic's content filter blocks it and the commit will fail mid-write.
- **Versioning (pre-1.0)**: tiny additive features = patch bump (x.y.z+1). Minor bumps only for new public API surface. Free to break — document deprecations in `docs/CHANGELOG.md` (most recent first, "Current" header pinned to the new version).
- **Release pattern**: every shipped version commits + pushes + tags + creates a GitHub release with notes from CHANGELOG.
- **`.spi.yml`**: SPI build matrix already configured with `documentation_targets: [OCCTSwiftTools]`. SPI submission is gated on v1.0.0 — don't submit early.

## What is explicitly out of scope

Per SPEC.md: selection/picking semantics, manipulator widgets, and dimension annotations all belong to **OCCTSwiftAIS** (one layer above) — do not implement them here. Also out: headless ray-tracing (use CADRays separately), Linux/Windows/Android, watchOS.

## Ecosystem context worth reading before non-trivial changes

- `~/Projects/OCCTSwift/CLAUDE.md` — kernel project conventions (this repo follows them)
- `~/Projects/OCCTSwift/docs/visualization-research.md` — *why* the three-layer cake exists
- `~/Projects/OCCTSwiftViewport/Sources/OCCTSwiftTools/` — the code being migrated in
