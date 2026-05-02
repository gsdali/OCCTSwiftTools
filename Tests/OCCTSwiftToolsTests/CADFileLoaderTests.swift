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
}
