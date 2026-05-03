import Testing
import simd
import OCCTSwift
import OCCTSwiftViewport
@testable import OCCTSwiftTools

@Suite("CADFileLoader.shapeToBodyAndMetadata")
struct CADFileLoaderTests {

    @Test func t_boxRoundTrip() {
        guard let box = Shape.box(width: 10, height: 5, depth: 3) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let (body, meta) = CADFileLoader.shapeToBodyAndMetadata(
            box, id: "box", color: SIMD4<Float>(0.7, 0.7, 0.7, 1.0)
        )
        guard let body, let meta else {
            Issue.record("shapeToBodyAndMetadata returned nil for a closed box")
            return
        }
        #expect(body.id == "box")
        #expect(body.vertexData.count % 6 == 0, "interleaved stride 6 (px,py,pz,nx,ny,nz)")
        #expect(body.indices.count % 3 == 0, "indices form triangles")
        #expect(body.indices.count > 0)
        #expect(body.faceIndices.count == body.indices.count / 3,
                "one source-face index per triangle")
        #expect(meta.faceIndices == body.faceIndices,
                "metadata.faceIndices mirrors body.faceIndices")
    }

    @Test func t_cylinderFaceCoverage() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else {
            Issue.record("Shape.cylinder returned nil")
            return
        }
        let (body, meta) = CADFileLoader.shapeToBodyAndMetadata(
            cyl, id: "cyl", color: SIMD4<Float>(0.5, 0.5, 0.5, 1.0)
        )
        guard let body, let meta else {
            Issue.record("cylinder produced no body/metadata")
            return
        }
        let uniqueFaces = Set(body.faceIndices)
        // OCCT cylinder = 3 faces (top cap, bottom cap, lateral surface).
        #expect(uniqueFaces.count >= 3,
                "cylinder triangulation should cover all 3 faces, got \(uniqueFaces.count)")
        #expect(meta.edgePolylines.count > 0, "cylinder has edges (circles + seam)")
    }

    @Test func t_meshParameterPresetsAreFiner() {
        // High-quality preset should be strictly finer than the default.
        #expect(CADFileLoader.highQualityMeshParams.deflection < MeshParameters.default.deflection)
        #expect(CADFileLoader.highQualityMeshParams.angle < MeshParameters.default.angle)
        // Tessellation preset trades CPU detail for GPU PN refinement.
        #expect(CADFileLoader.tessellationMeshParams.angle < MeshParameters.default.angle)
    }

    @Test func t_unknownExtensionReturnsNilFormat() {
        #expect(CADFileFormat(fileExtension: "xyz") == nil)
        #expect(CADFileFormat(fileExtension: "STEP") == .step)
        #expect(CADFileFormat(fileExtension: "stp") == .step)
        #expect(CADFileFormat(fileExtension: "BREP") == .brep)
        #expect(CADFileFormat(fileExtension: "brp") == .brep)
    }

    @Test func t_igesFormatRecognition() {
        #expect(CADFileFormat(fileExtension: "iges") == .iges)
        #expect(CADFileFormat(fileExtension: "IGES") == .iges)
        #expect(CADFileFormat(fileExtension: "igs") == .iges)
        #expect(CADFileFormat(fileExtension: "IGS") == .iges)
    }

    // MARK: - v0.4.1: ViewportBody.edgeIndices / vertices for AIS edge+vertex picking

    @Test func t_boxBodyHasEdgePickData() {
        guard let box = Shape.box(width: 2, height: 2, depth: 2) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let (body, meta) = CADFileLoader.shapeToBodyAndMetadata(
            box, id: "box", color: SIMD4<Float>(0.7, 0.7, 0.7, 1.0)
        )
        guard let body, let meta else {
            Issue.record("box conversion produced no body/metadata")
            return
        }

        // edgeIndices length must equal the total flattened segment count.
        let expectedSegments = meta.edgePolylines.reduce(0) { acc, poly in
            acc + max(poly.points.count - 1, 0)
        }
        #expect(body.edgeIndices.count == expectedSegments,
                "edgeIndices.count (\(body.edgeIndices.count)) should equal sum of (poly.count - 1) = \(expectedSegments)")

        // Every value in edgeIndices must be a valid source-edge index from the
        // metadata (i.e. round-trippable to a TopoDS_Edge handle).
        let validEdgeIndices = Set(meta.edgePolylines.map { Int32($0.edgeIndex) })
        for ei in body.edgeIndices {
            #expect(validEdgeIndices.contains(ei),
                    "edgeIndex \(ei) on body is not present in source edge enumeration")
        }
    }

    @Test func t_boxBodyVerticesAreSourceShapeIndexed() {
        // v0.5.0 (closes #10): body.vertices and body.vertexIndices follow
        // the source-shape convention so AIS can round-trip a picked
        // primitiveIndex back to TopoDS_Vertex via shape.vertex(at:).
        guard let box = Shape.box(width: 2, height: 2, depth: 2) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let (body, meta) = CADFileLoader.shapeToBodyAndMetadata(
            box, id: "box", color: SIMD4<Float>(0.7, 0.7, 0.7, 1.0)
        )
        guard let body, let meta else {
            Issue.record("box conversion produced no body/metadata")
            return
        }
        let sourceVerts = box.vertices()

        // body.vertices count and order match shape.vertices().
        #expect(body.vertices.count == sourceVerts.count,
                "body.vertices.count must equal shape.vertices().count for the source-shape convention")
        #expect(body.vertices.count > 0, "box has corner vertices")
        for i in 0..<body.vertices.count {
            let bv = body.vertices[i]
            let sv = sourceVerts[i]
            #expect(abs(Double(bv.x) - sv.x) < 1e-5, "vertex \(i) X drift")
            #expect(abs(Double(bv.y) - sv.y) < 1e-5, "vertex \(i) Y drift")
            #expect(abs(Double(bv.z) - sv.z) < 1e-5, "vertex \(i) Z drift")
        }

        // vertexIndices is now an explicit identity array, not empty —
        // protects against future renderer changes that drop the
        // empty-as-identity interpretation.
        #expect(body.vertexIndices.count == sourceVerts.count)
        for (i, idx) in body.vertexIndices.enumerated() {
            #expect(Int(idx) == i, "vertexIndices[\(i)] should be identity \(i), got \(idx)")
        }

        // metadata.vertices converged to the same source-shape convention.
        #expect(meta.vertices.count == sourceVerts.count)
        #expect(meta.vertices == body.vertices,
                "metadata.vertices and body.vertices must agree post-v0.5.0")
    }
}
