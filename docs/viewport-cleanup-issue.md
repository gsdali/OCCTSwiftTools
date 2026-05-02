# Viewport cleanup issue (filed against OCCTSwiftViewport)

This is a local copy of the issue body filed against `gsdali/OCCTSwiftViewport` to coordinate the v0.51.0 release that drops the now-extracted `OCCTSwiftTools` sub-product.

---

**Title:** Drop `OCCTSwiftTools` sub-product — extracted to standalone repo

**Body:**

The `OCCTSwiftTools` sub-product has been extracted to its own repo: <https://github.com/gsdali/OCCTSwiftTools>. This unblocks the v0.1.0 release of OCCTSwiftTools, which currently **cannot build** because SPM enforces target-name uniqueness across the package graph and both packages declare a target named `OCCTSwiftTools`:

```
error: multiple packages ('occtswifttools', 'occtswiftviewport') declare
targets with a conflicting name: 'OCCTSwiftTools'; target names need to
be unique across the package graph
```

So the migration is genuinely chicken-and-egg: viewport must ship a release that drops the conflicting target before OCCTSwiftTools v0.1.0 can build, and OCCTSwiftTools v0.1.0 must exist before any consumer can replace its viewport-side `"OCCTSwiftTools"` dep with the external package.

### What needs to change in this repo

1. Delete `Sources/OCCTSwiftTools/` (7 files: `BodyUtilities.swift`, `CADFileLoader.swift`, `CurveConverter.swift`, `ExportManager.swift`, `ScriptManifest.swift`, `SurfaceConverter.swift`, `WireConverter.swift`). All seven have already been copied verbatim into the new repo's `Sources/OCCTSwiftTools/`.
2. Remove the `OCCTSwiftTools` library product and target from `Package.swift`.
3. Decide what to do with `OCCTSwiftMetalDemo` (executable target) — it currently depends on the soon-to-be-deleted `OCCTSwiftTools` target. Three reasonable options:
   - **a.** Drop the demo target entirely in v0.51.0 (it's a dev aid, not part of the library product). Re-add later in a separate `OCCTSwiftViewport-Examples` repo if useful.
   - **b.** Keep the demo target but rewire its dep to the external package. Requires the external package to exist first; can be done in v0.52.0 after this repo tags v0.1.0.
   - **c.** Use a path-based dep (`.package(path: "../OCCTSwiftTools")`) in v0.51.0 to keep the demo building locally without a tagged release.

   Recommendation: **(a)** for v0.51.0 — minimum surface area, unblocks the OCCTSwiftTools release immediately.
4. Bump version, tag `v0.51.0`, add CHANGELOG entry noting:
   - **Breaking:** `OCCTSwiftTools` library product removed; consumers must migrate to <https://github.com/gsdali/OCCTSwiftTools> (>= 0.1.0).
   - Whatever was decided about the demo target.

### Coordination after this lands

Once `v0.51.0` is tagged here, the OCCTSwiftTools repo will:
1. Confirm `swift build` against viewport `from: "0.51.0"`.
2. Run the test suite (`OCCT_SERIAL=1 swift test --parallel --num-workers 1`).
3. Tag its own `v0.1.0` and publish the GitHub release.

Tracking on the OCCTSwiftTools side: the migrated source already lives on `main` ([commit](https://github.com/gsdali/OCCTSwiftTools/commits/main)); only the build/test/tag steps remain.
