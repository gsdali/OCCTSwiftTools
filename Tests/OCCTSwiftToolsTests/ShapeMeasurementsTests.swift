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

    // MARK: - v0.3.0: centroids + perimeters

    @Test func t_boxFaceCentroidsLieInsideFaceBounds() {
        guard let box = Shape.box(width: 2, height: 3, depth: 5) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let m = box.measure()
        #expect(m.faceCentroids.count == 6,
                "one centroid per face, parallel to faceAreas")
        // For a non-trimmed box face the centroid must lie within the face's
        // axis-aligned bounding box. We don't assume OCCT's box-positioning
        // convention — `Shape.box` may anchor at origin or center.
        let faces = box.faces()
        for (i, c) in m.faceCentroids.enumerated() {
            let b = faces[i].bounds
            #expect(c.x >= b.min.x - 1e-6 && c.x <= b.max.x + 1e-6,
                    "face \(i) centroid X=\(c.x) outside [\(b.min.x), \(b.max.x)]")
            #expect(c.y >= b.min.y - 1e-6 && c.y <= b.max.y + 1e-6,
                    "face \(i) centroid Y=\(c.y) outside [\(b.min.y), \(b.max.y)]")
            #expect(c.z >= b.min.z - 1e-6 && c.z <= b.max.z + 1e-6,
                    "face \(i) centroid Z=\(c.z) outside [\(b.min.z), \(b.max.z)]")
        }
    }

    @Test func t_boxFacePerimetersMatchExpectedTotals() {
        guard let box = Shape.box(width: 2, height: 3, depth: 5) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let m = box.measure()
        #expect(m.facePerimeters.count == 6)
        // Box has 3 distinct face shapes:
        //   2×3 face: perimeter 2(2+3) = 10 — 2 faces → 20
        //   3×5 face: perimeter 2(3+5) = 16 — 2 faces → 32
        //   2×5 face: perimeter 2(2+5) = 14 — 2 faces → 28
        // Total = 20 + 32 + 28 = 80
        #expect(abs(m.totalFacePerimeter - 80.0) < 1e-6,
                "expected 80.0 mm total face perimeter, got \(m.totalFacePerimeter)")
        // No face should be missing its perimeter (no nils for a closed box).
        #expect(m.facePerimeters.allSatisfy { $0 != nil },
                "all box faces have a closed outer wire")
    }

    @Test func t_cylinderTopBottomCentroidsAreOnAxis() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else {
            Issue.record("Shape.cylinder returned nil")
            return
        }
        // Find the two circular cap faces by their area: π·r² = π·25 ≈ 78.54.
        // Their centroids should lie on the cylinder axis (X=Y=0 in OCCT's
        // default cylinder placement, which puts the axis on Z).
        let m = cyl.measure()
        let capArea = .pi * 25.0
        var capCount = 0
        for (i, area) in m.faceAreas.enumerated() {
            if abs(area - capArea) < 1e-3 {
                capCount += 1
                let c = m.faceCentroids[i]
                #expect(abs(c.x) < 1e-6, "cap \(i) centroid X=\(c.x), expected 0")
                #expect(abs(c.y) < 1e-6, "cap \(i) centroid Y=\(c.y), expected 0")
            }
        }
        #expect(capCount == 2, "cylinder has 2 circular caps, found \(capCount)")
    }
}
