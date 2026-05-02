# OCCTSwiftTools

[![License](https://img.shields.io/badge/license-LGPL--2.1-blue)](LICENSE)

The bridge layer between [OCCTSwift](https://github.com/gsdali/OCCTSwift) (B-Rep modeling kernel) and [OCCTSwiftViewport](https://github.com/gsdali/OCCTSwiftViewport) (Metal viewport).

> Status: **v0.1.0**. The migration out of OCCTSwiftViewport's sub-product slot is complete. See [docs/CHANGELOG.md](docs/CHANGELOG.md) and [SPEC.md](SPEC.md).

## What it does

```swift
import OCCTSwift
import OCCTSwiftTools

let box = Shape.box(width: 10, height: 5, depth: 3)!
let body = ViewportBody.from(box)!     // ← this lives here
```

Plus one-shot file loaders:

```swift
let bodies = try CADFile.loadSTEP(at: stepURL)
let mesh   = try CADFile.loadSTL(at: stlURL)
```

## Architecture position

```
OCCTSwiftAIS          (selection / manipulator / dimensions; sibling repo)
       ↑
OCCTSwiftTools        ← this repo
       ↑      ↑
OCCTSwift   OCCTSwiftViewport
(B-Rep)     (Metal renderer)
```

OCCTSwiftTools is the only repo that depends on **both** sibling kernels. OCCTSwiftAIS depends on this; the two kernels stay decoupled from each other.

## Installation

```swift
.package(url: "https://github.com/gsdali/OCCTSwiftTools.git", from: "0.1.0"),
```

## Supported platforms

| Platform | Status |
|---|---|
| macOS 15+ arm64 | Supported |
| iOS 18+ device + simulator arm64 | Supported |
| visionOS 1+ device + simulator arm64 | Supported |
| tvOS 18+ device + simulator arm64 | Supported |

The platform floor is the **higher** of OCCTSwift's (12.0 / 15.0) and OCCTSwiftViewport's (15.0 / 18.0).

## Status

`v0.1.0` shipped the wholesale migration from OCCTSwiftViewport's `OCCTSwiftTools` sub-product. Requires `OCCTSwiftViewport` ≥ `v0.51.0` (the release that drops the conflicting target name). See [docs/CHANGELOG.md](docs/CHANGELOG.md) for release history and [SPEC.md](SPEC.md) for the public API surface and roadmap.

## License

LGPL 2.1 (matching OCCT). See [LICENSE](LICENSE).
