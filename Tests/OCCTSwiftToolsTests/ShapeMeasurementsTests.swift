import Testing
import OCCTSwift
@testable import OCCTSwiftTools

@Suite("ShapeMeasurements")
struct ShapeMeasurementsTests {

    @Test func t_boxFaceAreasMatchExpectedTotals() {
        guard let box = Shape.box(width: 2, height: 3, depth: 5) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let m = box.measure()
        // Box has 6 faces. Total surface area = 2*(2*3 + 3*5 + 2*5) = 2*31 = 62.
        #expect(m.faceAreas.count == 6)
        #expect(abs(m.totalFaceArea - 62.0) < 1e-6,
                "expected 62.0 mm², got \(m.totalFaceArea)")
        // Areas should occur in 3 pairs (front/back, top/bottom, left/right) of equal value.
        let sorted = m.faceAreas.sorted()
        #expect(abs(sorted[0] - sorted[1]) < 1e-6)
        #expect(abs(sorted[2] - sorted[3]) < 1e-6)
        #expect(abs(sorted[4] - sorted[5]) < 1e-6)
    }

    @Test func t_boxEdgeLengthsMatchExpectedTotals() {
        guard let box = Shape.box(width: 2, height: 3, depth: 5) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let m = box.measure()
        // Box has 12 edges: 4 of length 2, 4 of length 3, 4 of length 5.
        // Total = 4*(2+3+5) = 40.
        #expect(m.edgeLengths.count == 12)
        #expect(abs(m.totalEdgeLength - 40.0) < 1e-6,
                "expected 40.0 mm, got \(m.totalEdgeLength)")
    }

    @Test func t_cylinderTotalsAreFinite() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else {
            Issue.record("Shape.cylinder returned nil")
            return
        }
        let m = cyl.measure()
        // Cylinder = 3 faces (top, bottom, lateral) + edges (2 circles + 1 seam).
        #expect(m.faceAreas.count >= 3)
        #expect(m.totalFaceArea > 0)
        #expect(m.totalFaceArea.isFinite)
        #expect(m.totalEdgeLength > 0)
        #expect(m.totalEdgeLength.isFinite)
    }

    @Test func t_metadataIncludesMeasurementsWhenRequested() {
        guard let box = Shape.box(width: 1, height: 1, depth: 1) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let (_, metaOff) = CADFileLoader.shapeToBodyAndMetadata(
            box, id: "off", color: .init(0.7, 0.7, 0.7, 1.0)
        )
        let (_, metaOn) = CADFileLoader.shapeToBodyAndMetadata(
            box, id: "on", color: .init(0.7, 0.7, 0.7, 1.0),
            includeMeasurements: true
        )
        #expect(metaOff?.measurements == nil, "off by default")
        if let m = metaOn?.measurements {
            #expect(m.faceAreas.count == 6)
            #expect(abs(m.totalFaceArea - 6.0) < 1e-6, "unit cube has 6 mm² total")
        } else {
            Issue.record("includeMeasurements:true should populate metadata.measurements")
        }
    }
}
