// CADFileLoader.swift
// OCCTSwiftTools
//
// Bridge layer: wraps OCCTSwiftIO's headless `ShapeLoader` to produce
// `ViewportBody` + `CADBodyMetadata` from CAD files. The file-format,
// progress, exporter, and manifest types live in `OCCTSwiftIO`; this file
// owns only the Shape → Body bridge logic.

import Foundation
import simd
import OCCTSwift
import OCCTSwiftViewport
@_exported import OCCTSwiftIO

/// Result of loading a CAD file with renderable bodies attached.
///
/// For headless / shape-only loads (no Viewport dep), use
/// `OCCTSwiftIO.ShapeLoader.load` and `ShapeLoadResult` directly.
public struct CADLoadResult: @unchecked Sendable {
    public var bodies: [ViewportBody]
    public var metadata: [String: CADBodyMetadata]
    public var shapes: [Shape]
    public var dimensions: [DimensionInfo]
    public var geomTolerances: [GeomToleranceInfo]
    public var datums: [DatumInfo]

    public init(bodies: [ViewportBody] = [], metadata: [String: CADBodyMetadata] = [:],
                shapes: [Shape] = [], dimensions: [DimensionInfo] = [],
                geomTolerances: [GeomToleranceInfo] = [], datums: [DatumInfo] = []) {
        self.bodies = bodies
        self.metadata = metadata
        self.shapes = shapes
        self.dimensions = dimensions
        self.geomTolerances = geomTolerances
        self.datums = datums
    }
}

/// Loads CAD files via OCCTSwiftIO and bridges the resulting shapes to
/// `ViewportBody` + `CADBodyMetadata` for renderable + pickable consumers.
public enum CADFileLoader {

    /// Loads a CAD file and returns viewport bodies with selection metadata.
    /// - Parameter progress: optional progress + cancellation observer. Honored
    ///   by `.step` and `.iges` formats only — STL/OBJ/BREP loaders are
    ///   single-call upstream and don't surface progress. If `progress.shouldCancel()`
    ///   returns `true`, the import throws `OCCTSwift.ImportError.cancelled`.
    public static func load(
        from url: URL,
        format: CADFileFormat,
        progress: ImportProgress? = nil
    ) async throws -> CADLoadResult {
        let ioResult = try await ShapeLoader.load(from: url, format: format, progress: progress)
        return bridgeWithFallback(
            ioResult: ioResult, idPrefix: format.rawValue,
            url: url, format: format, progress: progress
        )
    }

    /// Loads bodies from a script manifest (manifest.json + BREP files).
    public static func loadFromManifest(at url: URL) throws -> CADLoadResult {
        let ioResult = try ShapeLoader.loadFromManifest(at: url)

        var bodies: [ViewportBody] = []
        var metadata: [String: CADBodyMetadata] = [:]
        var shapes: [Shape] = []

        for (index, pair) in ioResult.shapesWithColors.enumerated() {
            let descriptor = ioResult.manifest?.bodies[index]
            let bodyID = "script-\(descriptor?.id ?? "\(index)")"
            let rgba = pair.color ?? SIMD4<Float>(0.7, 0.7, 0.7, 1.0)

            let (body, meta) = shapeToBodyAndMetadata(pair.shape, id: bodyID, color: rgba)
            if let body {
                bodies.append(body)
                shapes.append(pair.shape)
                if let meta { metadata[bodyID] = meta }
            }
        }

        return CADLoadResult(bodies: bodies, metadata: metadata, shapes: shapes)
    }

    // MARK: - Bridge with STL/IGES robust fallback

    /// STL and IGES files commonly fail the primary loader → bridge path
    /// (mesh generation returns nil because the input has gaps OCCT's basic
    /// importer can't close). Fall back to the sewing/healing variant on
    /// per-shape bridge failure. STEP / OBJ / BREP have no such fallback —
    /// the primary loader is the only one.
    private static func bridgeWithFallback(
        ioResult: ShapeLoadResult,
        idPrefix: String,
        url: URL,
        format: CADFileFormat,
        progress: ImportProgress?
    ) -> CADLoadResult {
        var bodies: [ViewportBody] = []
        var metadata: [String: CADBodyMetadata] = [:]
        var shapes: [Shape] = []
        var needsRobustReload = false

        for (index, pair) in ioResult.shapesWithColors.enumerated() {
            let bodyID = "\(idPrefix)-\(index)"
            let rgba = pair.color ?? SIMD4<Float>(0.7, 0.7, 0.7, 1.0)
            let stl = (format == .stl)

            let (body, meta) = shapeToBodyAndMetadata(pair.shape, id: bodyID, color: rgba, stl: stl)
            if let body {
                bodies.append(body)
                shapes.append(pair.shape)
                if let meta { metadata[bodyID] = meta }
            } else if format == .stl || format == .iges {
                needsRobustReload = true
                break
            }
        }

        // Single-shape STL/IGES fallback path: re-load via the robust loader
        // and bridge again. Both formats currently produce a single shape.
        if needsRobustReload {
            return reloadRobustAndBridge(idPrefix: idPrefix, url: url, format: format, progress: progress)
        }

        return CADLoadResult(
            bodies: bodies, metadata: metadata, shapes: shapes,
            dimensions: ioResult.dimensions,
            geomTolerances: ioResult.geomTolerances,
            datums: ioResult.datums
        )
    }

    private static func reloadRobustAndBridge(
        idPrefix: String, url: URL, format: CADFileFormat, progress: ImportProgress?
    ) -> CADLoadResult {
        // The robust reload mirrors the primary load's blocking call — we're
        // already on a detached task at this point (outer load() is async),
        // so a sync call is fine.
        do {
            let ioRobust: ShapeLoadResult
            switch format {
            case .stl:
                let robust = try Shape.loadSTLRobust(from: url)
                ioRobust = ShapeLoadResult(shapesWithColors: [(shape: robust, color: nil)])
            case .iges:
                let robust = try Shape.loadIGESRobust(from: url, progress: progress)
                ioRobust = ShapeLoadResult(shapesWithColors: [(shape: robust, color: nil)])
            default:
                return CADLoadResult()
            }

            var bodies: [ViewportBody] = []
            var metadata: [String: CADBodyMetadata] = [:]
            var shapes: [Shape] = []
            for (index, pair) in ioRobust.shapesWithColors.enumerated() {
                let bodyID = "\(idPrefix)-\(index)"
                let rgba = pair.color ?? SIMD4<Float>(0.7, 0.7, 0.7, 1.0)
                let (body, meta) = shapeToBodyAndMetadata(pair.shape, id: bodyID, color: rgba)
                if let body {
                    bodies.append(body)
                    shapes.append(pair.shape)
                    if let meta { metadata[bodyID] = meta }
                } else {
                    shapes.append(pair.shape)
                }
            }
            return CADLoadResult(bodies: bodies, metadata: metadata, shapes: shapes)
        } catch {
            return CADLoadResult()
        }
    }

    // MARK: - Mesh parameter presets

    /// High-quality mesh parameters for smooth curved surface rendering (no GPU tessellation).
    public static let highQualityMeshParams: MeshParameters = {
        var p = MeshParameters.default
        p.deflection = 0.03          // 3× finer than default 0.1
        p.angle = 0.2                // ~11° (vs default 0.5 rad ≈ 29°)
        p.angleInterior = 0.2        // Match interior B-spline quality
        p.controlSurfaceDeflection = true
        p.inParallel = true
        return p
    }()

    /// Moderate mesh parameters for GPU tessellation (PN triangles).
    /// Balanced: enough triangles for good normals, large enough for visible PN displacement.
    public static let tessellationMeshParams: MeshParameters = {
        var p = MeshParameters.default
        p.deflection = 0.1           // OCCT default — moderate triangle density
        p.angle = 0.35               // ~20° — good normal quality for PN patches
        p.controlSurfaceDeflection = true
        p.inParallel = true
        return p
    }()

    // MARK: - Shape → Body bridge

    /// Converts an OCCTSwift Shape to a ViewportBody and optional metadata.
    /// - Parameter stl: If true, uses coarser deflection suitable for pre-tessellated STL data
    /// - Parameter deflection: Custom linear deflection override. Lower = smoother (default 0.1, STL uses 1.0).
    /// - Parameter gpuTessellation: If true, uses coarser CPU mesh (GPU PN triangles will refine).
    /// - Parameter includeMeasurements: If true, populates `metadata.measurements`
    ///   with per-face areas and per-edge lengths (via `Shape.measure`). Off by
    ///   default — face-area iteration is O(faces) and not free for large assemblies.
    public static func shapeToBodyAndMetadata(
        _ shape: Shape,
        id bodyID: String,
        color rgba: SIMD4<Float>,
        stl: Bool = false,
        deflection customDeflection: Double? = nil,
        gpuTessellation: Bool = false,
        includeMeasurements: Bool = false
    ) -> (ViewportBody?, CADBodyMetadata?) {
        let measurements: ShapeMeasurements? = includeMeasurements ? shape.measure() : nil
        let mesh: Mesh?
        if let customDeflection {
            mesh = shape.mesh(linearDeflection: customDeflection)
        } else if stl {
            mesh = shape.mesh(linearDeflection: 1.0)
        } else if gpuTessellation {
            // Coarser CPU mesh — GPU PN tessellation will refine
            mesh = shape.mesh(parameters: tessellationMeshParams)
        } else {
            // Default: fine CPU mesh for smooth rendering without GPU tessellation.
            mesh = shape.mesh(parameters: highQualityMeshParams)
        }
        guard let mesh else {
            let edgePolylines = extractEdgePolylines(from: shape)
            if !edgePolylines.isEmpty {
                let edges = edgePolylines.map { $0.points }
                let pickVerts = sourceShapeVertexPickData(from: shape)
                let edgeIndices = flattenEdgeIndices(edgePolylines)
                let body = ViewportBody(
                    id: bodyID, vertexData: [], indices: [],
                    edges: edges,
                    edgeIndices: edgeIndices,
                    vertices: pickVerts.positions,
                    vertexIndices: pickVerts.indices,
                    color: rgba
                )
                let meta = CADBodyMetadata(
                    faceIndices: [], edgePolylines: edgePolylines,
                    vertices: pickVerts.positions,
                    measurements: measurements
                )
                return (body, meta)
            }
            return (nil, nil)
        }

        let vertexCount = mesh.vertexCount
        var vertexData: [Float] = []
        vertexData.reserveCapacity(vertexCount * 6)
        let positions = mesh.vertices
        let normals = mesh.normals
        for i in 0..<vertexCount {
            let p = positions[i]
            let n = normals[i]
            vertexData.append(contentsOf: [p.x, p.y, p.z, n.x, n.y, n.z])
        }

        let triangles = mesh.trianglesWithFaces()
        var faceIndices: [Int32] = []
        faceIndices.reserveCapacity(triangles.count)
        for tri in triangles {
            faceIndices.append(tri.faceIndex)
        }

        let indices = mesh.indices

        // Apply crease-aware normal smoothing for smooth curved surfaces
        NormalSmoothing.smoothNormals(vertexData: &vertexData, indices: indices)

        let edgePolylines = extractEdgePolylines(from: shape)
        let edges = edgePolylines.map { $0.points }
        let pickVerts = sourceShapeVertexPickData(from: shape)
        let edgeIndices = flattenEdgeIndices(edgePolylines)

        let body = ViewportBody(
            id: bodyID, vertexData: vertexData, indices: indices,
            edges: edges, faceIndices: faceIndices,
            edgeIndices: edgeIndices,
            vertices: pickVerts.positions,
            vertexIndices: pickVerts.indices,
            color: rgba
        )
        let meta = CADBodyMetadata(
            faceIndices: faceIndices, edgePolylines: edgePolylines,
            vertices: pickVerts.positions,
            measurements: measurements
        )

        return (body, meta)
    }

    // MARK: - Edge / Vertex extraction helpers

    /// Flatten polyline-keyed edge indices into the per-segment array
    /// `ViewportBody.edgeIndices` expects. A polyline of N points contributes
    /// (N - 1) line segments, each tagged with the source edge's index.
    private static func flattenEdgeIndices(
        _ edgePolylines: [(edgeIndex: Int, points: [SIMD3<Float>])]
    ) -> [Int32] {
        var result: [Int32] = []
        for (edgeIndex, points) in edgePolylines {
            let segments = max(points.count - 1, 0)
            if segments > 0 {
                result.append(contentsOf: repeatElement(Int32(edgeIndex), count: segments))
            }
        }
        return result
    }

    private static func extractEdgePolylines(
        from shape: Shape
    ) -> [(edgeIndex: Int, points: [SIMD3<Float>])] {
        let count = shape.edgeCount
        var result: [(edgeIndex: Int, points: [SIMD3<Float>])] = []
        result.reserveCapacity(count)

        for i in 0..<count {
            guard let polyline = shape.edgePolyline(at: i, deflection: 0.005) else { continue }
            let floatPoints = polyline.map { SIMD3<Float>(Float($0.x), Float($0.y), Float($0.z)) }
            guard floatPoints.count >= 2 else { continue }
            result.append((edgeIndex: i, points: floatPoints))
        }

        return result
    }

    /// Collect source-shape vertices and their identity index array for the
    /// vertex-pick pass. Indexing matches `shape.vertices()` so consumers can
    /// round-trip a picked `primitiveIndex` back to a `TopoDS_Vertex` via
    /// `shape.vertex(at: primitiveIndex)`.
    private static func sourceShapeVertexPickData(
        from shape: Shape
    ) -> (positions: [SIMD3<Float>], indices: [Int32]) {
        let sourceVerts = shape.vertices()
        let positions = sourceVerts.map {
            SIMD3<Float>(Float($0.x), Float($0.y), Float($0.z))
        }
        let indices = (0..<sourceVerts.count).map(Int32.init)
        return (positions, indices)
    }
}
