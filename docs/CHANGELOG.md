# Changelog

Most recent first. Pre-1.0: free to break; deprecations documented here.

## Current — v0.1.0 (unreleased)

**Status:** source migration complete; release **blocked** on [OCCTSwiftViewport#22](https://github.com/gsdali/OCCTSwiftViewport/issues/22) (target-name collision — both packages currently declare a target named `OCCTSwiftTools`, which SPM rejects across the package graph).

**What landed:**
- Migrated 7 source files verbatim from OCCTSwiftViewport's sub-product slot:
  - `BodyUtilities`, `CADFileLoader`, `CurveConverter`, `SurfaceConverter`, `WireConverter`, `ExportManager`, `ScriptManifest`.
- Public API surface as documented in [SPEC.md](../SPEC.md) "Public API (v0.1.0 — actual migrated surface)".
- Test suites in `Tests/OCCTSwiftToolsTests/` covering body conversion, edge/surface converters, export round-trips, and manifest Codable round-trip. Geometry generated at runtime; no fixture files.
- SPEC.md rewritten — earlier drafts sketched a `ViewportBody.from(...)` extension and a `CADFile` enum with `loadIGES`/`loadGLTF`. Those were aspirational and did not match what was actually built; the spec now documents the real surface, with IGES/glTF parked as v0.2/v0.3 wishlist.

**Known constraints:**
- Tests must run with `OCCT_SERIAL=1 swift test --parallel --num-workers 1` due to a known NCollection container-overflow race in OCCT on arm64 macOS.
- Platform floor is the higher of OCCTSwift's and OCCTSwiftViewport's: `iOS 18 / macOS 15 / visionOS 1 / tvOS 18`.

**Coordination:** OCCTSwiftViewport will ship `v0.51.0` dropping the `OCCTSwiftTools` library product/target. Once that tag exists and `swift build` here is green, this repo will tag `v0.1.0` and publish the release.
