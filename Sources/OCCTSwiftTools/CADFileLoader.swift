// CADFileLoader.swift
// OCCTSwiftTools
//
// Bridges OCCTSwift geometry to ViewportBody + metadata for sub-body selection.
// Supports STEP, STL, OBJ, and BREP file formats.

import Foundation
import simd
import OCCTSwift
import OCCTSwiftViewport

/// Metadata extracted from OCCTSwift for sub-body selection (face, edge, vertex).
public struct CADBodyMetadata: Sendable {
    /// Per-triangle face index (parallel to ViewportBody.faceIndices).
    public let faceIndices: [Int32]

    /// Edge polylines with their edge indices for edge selection.
    public let edgePolylines: [(edgeIndex: Int, points: [SIMD3<Float>])]

    /// Deduplicated edge endpoint vertices for vertex selection.
    public let vertices: [SIMD3<Float>]

    /// Optional per-face area + per-edge length report. Populated only when the
    /// caller passes `includeMeasurements: true`. AIS' dimension widget uses
    /// this to label picked faces/edges with their scalar measurement.
    public let measurements: ShapeMeasurements?

    public init(
        faceIndices: [Int32],
        edgePolylines: [(edgeIndex: Int, points: [SIMD3<Float>])],
        vertices: [SIMD3<Float>],
        measurements: ShapeMeasurements? = nil
    ) {
        self.faceIndices = faceIndices
        self.edgePolylines = edgePolylines
        self.vertices = vertices
        self.measurements = measurements
    }
}

/// Result of loading a CAD file.
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

/// Supported CAD file formats.
public enum CADFileFormat: String, Sendable {
    case step
    case stl
    case obj
    case brep
    case iges

    public init?(fileExtension ext: String) {
        switch ext.lowercased() {
        case "step", "stp":
            self = .step
        case "stl":
            self = .stl
        case "obj":
            self = .obj
        case "brep", "brp":
            self = .brep
        case "iges", "igs":
            self = .iges
        default:
            return nil
        }
    }
}

/// Loads CAD files via OCCTSwift and converts to ViewportBody arrays.
public enum CADFileLoader {

    /// Loads a CAD file and returns viewport bodies with selection metadata.
    /// - Parameter progress: optional progress + cancellation observer. Honored
    ///   by `.step` and `.iges` formats only — STL/OBJ/BREP loaders are
    ///   single-call upstream and don't surface progress. Pass an
    ///   `ImportProgressClosure` for closure-style usage. If `progress.shouldCancel()`
    ///   returns `true`, the import throws `OCCTSwift.ImportError.cancelled`.
    public static func load(
        from url: URL,
        format: CADFileFormat,
        progress: ImportProgress? = nil
    ) async throws -> CADLoadResult {
        try await Task.detached {
            try loadSync(from: url, format: format, progress: progress)
        }.value
    }

    private static func loadSync(
        from url: URL,
        format: CADFileFormat,
        progress: ImportProgress?
    ) throws -> CADLoadResult {
        switch format {
        case .step:
            return try loadSTEP(from: url, progress: progress)
        case .stl:
            return try loadSTL(from: url)
        case .obj:
            return try loadOBJ(from: url)
        case .brep:
            return try loadBREP(from: url)
        case .iges:
            return try loadIGES(from: url, progress: progress)
        }
    }

    // MARK: - STEP Loading

    private static func loadSTEP(from url: URL, progress: ImportProgress? = nil) throws -> CADLoadResult {
        let doc = try Document.load(from: url, progress: progress)
        let shapesWithColors = doc.shapesWithColors()

        var bodies: [ViewportBody] = []
        var metadata: [String: CADBodyMetadata] = [:]
        var shapes: [Shape] = []

        for (index, pair) in shapesWithColors.enumerated() {
            let shape = pair.shape
            let color = pair.color

            let bodyID = "step-\(index)"

            let rgba: SIMD4<Float>
            if let c = color {
                rgba = SIMD4<Float>(Float(c.red), Float(c.green), Float(c.blue), Float(c.alpha))
            } else {
                rgba = SIMD4<Float>(0.7, 0.7, 0.7, 1.0)
            }

            let (body, meta) = shapeToBodyAndMetadata(shape, id: bodyID, color: rgba)
            if let body {
                bodies.append(body)
                shapes.append(shape)
                if let meta {
                    metadata[bodyID] = meta
                }
            }
        }

        let dimensions = doc.dimensions
        let geomTolerances = doc.geomTolerances
        let datums = doc.datums

        return CADLoadResult(
            bodies: bodies, metadata: metadata, shapes: shapes,
            dimensions: dimensions, geomTolerances: geomTolerances, datums: datums
        )
    }

    // MARK: - STL Loading

    private static func loadSTL(from url: URL) throws -> CADLoadResult {
        let shape = try Shape.loadSTL(from: url)

        let bodyID = "stl-0"
        let color = SIMD4<Float>(0.7, 0.7, 0.7, 1.0)

        let (body, meta) = shapeToBodyAndMetadata(shape, id: bodyID, color: color, stl: true)
        guard let body else {
            let robust = try Shape.loadSTLRobust(from: url)
            let (body2, meta2) = shapeToBodyAndMetadata(robust, id: bodyID, color: color)
            guard let body2 else {
                return CADLoadResult(bodies: [], metadata: [:], shapes: [robust])
            }
            var metadata: [String: CADBodyMetadata] = [:]
            if let meta2 { metadata[bodyID] = meta2 }
            return CADLoadResult(bodies: [body2], metadata: metadata, shapes: [robust])
        }

        var metadata: [String: CADBodyMetadata] = [:]
        if let meta { metadata[bodyID] = meta }
        return CADLoadResult(bodies: [body], metadata: metadata, shapes: [shape])
    }

    // MARK: - OBJ Loading

    private static func loadOBJ(from url: URL) throws -> CADLoadResult {
        let shape = try Shape.loadOBJ(from: url)
        let bodyID = "obj-0"
        let color = SIMD4<Float>(0.7, 0.7, 0.7, 1.0)

        let (body, meta) = shapeToBodyAndMetadata(shape, id: bodyID, color: color)
        guard let body else {
            return CADLoadResult(bodies: [], metadata: [:], shapes: [shape])
        }

        var metadata: [String: CADBodyMetadata] = [:]
        if let meta { metadata[bodyID] = meta }
        return CADLoadResult(bodies: [body], metadata: metadata, shapes: [shape])
    }

    // MARK: - BREP Loading

    private static func loadBREP(from url: URL) throws -> CADLoadResult {
        let shape = try Shape.loadBREP(from: url)
        let bodyID = "brep-0"
        let color = SIMD4<Float>(0.7, 0.7, 0.7, 1.0)

        let (body, meta) = shapeToBodyAndMetadata(shape, id: bodyID, color: color)
        guard let body else {
            return CADLoadResult(bodies: [], metadata: [:], shapes: [shape])
        }

        var metadata: [String: CADBodyMetadata] = [:]
        if let meta { metadata[bodyID] = meta }
        return CADLoadResult(bodies: [body], metadata: metadata, shapes: [shape])
    }

    // MARK: - IGES Loading

    private static func loadIGES(from url: URL, progress: ImportProgress? = nil) throws -> CADLoadResult {
        let shape = try Shape.loadIGES(from: url, progress: progress)
        let bodyID = "iges-0"
        let color = SIMD4<Float>(0.7, 0.7, 0.7, 1.0)

        let (body, meta) = shapeToBodyAndMetadata(shape, id: bodyID, color: color)
        guard let body else {
            // Fall back to the sewing/healing variant — IGES files commonly
            // ship with gaps OCCT's basic importer won't close. The fallback
            // re-imports, so progress will pass through 0..1 a second time.
            let robust = try Shape.loadIGESRobust(from: url, progress: progress)
            let (body2, meta2) = shapeToBodyAndMetadata(robust, id: bodyID, color: color)
            guard let body2 else {
                return CADLoadResult(bodies: [], metadata: [:], shapes: [robust])
            }
            var metadata: [String: CADBodyMetadata] = [:]
            if let meta2 { metadata[bodyID] = meta2 }
            return CADLoadResult(bodies: [body2], metadata: metadata, shapes: [robust])
        }

        var metadata: [String: CADBodyMetadata] = [:]
        if let meta { metadata[bodyID] = meta }
        return CADLoadResult(bodies: [body], metadata: metadata, shapes: [shape])
    }

    // MARK: - Manifest Loading

    /// Loads bodies from a script manifest (manifest.json + BREP files).
    public static func loadFromManifest(at url: URL) throws -> CADLoadResult {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(ScriptManifest.self, from: data)
        let baseDir = url.deletingLastPathComponent()

        var bodies: [ViewportBody] = []
        var metadata: [String: CADBodyMetadata] = [:]
        var shapes: [Shape] = []

        for (index, descriptor) in manifest.bodies.enumerated() {
            let fileURL = baseDir.appendingPathComponent(descriptor.file)
            guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }

            let shape = try Shape.loadBREP(from: fileURL)
            let bodyID = "script-\(descriptor.id ?? "\(index)")"
            let color = descriptor.color ?? SIMD4<Float>(0.7, 0.7, 0.7, 1.0)

            let (body, meta) = shapeToBodyAndMetadata(shape, id: bodyID, color: color)
            if let body {
                bodies.append(body)
                shapes.append(shape)
                if let meta { metadata[bodyID] = meta }
            }
        }

        return CADLoadResult(bodies: bodies, metadata: metadata, shapes: shapes)
    }

    // MARK: - Shape → Body Conversion

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

    // MARK: - Edge Index Flattening (v0.4.1)

    /// Flatten polyline-keyed edge indices into the per-segment array
    /// `ViewportBody.edgeIndices` expects. A polyline of N points contributes
    /// (N - 1) line segments, each tagged with the source edge's index.
    /// Result length equals total flat segment count, matching the renderer's
    /// flattened-line layout used by the GPU edge-pick pass.
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

    // MARK: - Edge Extraction

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

    // MARK: - Vertex Pick Data (v0.5.0 — source-shape convention)

    /// Collect source-shape vertices and their identity index array for the
    /// vertex-pick pass. Indexing matches `shape.vertices()` so consumers can
    /// round-trip a picked `primitiveIndex` back to a `TopoDS_Vertex` via
    /// `shape.vertex(at: primitiveIndex)`.
    ///
    /// Replaces v0.4.1's polyline-endpoint-deduplication approach, which
    /// rendered the same number of points for typical solids but in a
    /// different order — breaking AIS' `Selection.vertices` round-trip.
    /// Closes [#10](https://github.com/gsdali/OCCTSwiftTools/issues/10).
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
