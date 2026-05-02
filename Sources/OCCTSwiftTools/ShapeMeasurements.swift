// ShapeMeasurements.swift
// OCCTSwiftTools
//
// Per-face area + per-edge length reports for OCCTSwiftAIS' dimension widget.

import OCCTSwift

/// Measurements computed from a `Shape`'s topology, indexed parallel to its
/// face / edge enumeration so AIS-layer consumers can resolve a picked
/// face / edge index directly to its scalar measurement.
public struct ShapeMeasurements: Sendable {
    /// `faceAreas[i]` is the area of `shape.faces()[i]`.
    public let faceAreas: [Double]

    /// `edgeLengths[i]` is the arc length of `shape.edge(at: i)` (0..<shape.edgeCount).
    public let edgeLengths: [Double]

    public init(faceAreas: [Double], edgeLengths: [Double]) {
        self.faceAreas = faceAreas
        self.edgeLengths = edgeLengths
    }

    /// Sum of all face areas — useful as a quick total-surface metric.
    public var totalFaceArea: Double { faceAreas.reduce(0, +) }

    /// Sum of all edge lengths.
    public var totalEdgeLength: Double { edgeLengths.reduce(0, +) }
}

extension Shape {
    /// Compute per-face area + per-edge length for this shape.
    /// - Parameter linearTolerance: tolerance forwarded to `Face.area(tolerance:)`.
    ///   Defaults to OCCT's `1e-6` — tighten only if you hit precision issues.
    public func measure(linearTolerance: Double = 1e-6) -> ShapeMeasurements {
        let faceAreas = faces().map { $0.area(tolerance: linearTolerance) }

        let count = edgeCount
        var edgeLengths: [Double] = []
        edgeLengths.reserveCapacity(count)
        for i in 0..<count {
            edgeLengths.append(edge(at: i)?.length ?? 0)
        }

        return ShapeMeasurements(faceAreas: faceAreas, edgeLengths: edgeLengths)
    }
}
