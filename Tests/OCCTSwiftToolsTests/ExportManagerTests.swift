import Testing
import Foundation
import OCCTSwift
@testable import OCCTSwiftTools

@Suite("ExportManager")
struct ExportManagerTests {

    /// Stage temp files under /tmp per OCCTSwift convention — never under Tests/.
    private static func tempURL(suffix: String) -> URL {
        URL(fileURLWithPath: "/tmp/occtswifttools-\(UUID().uuidString)-\(suffix)")
    }

    @Test func t_exportFormatExtensions() {
        #expect(ExportFormat.obj.fileExtension == "obj")
        #expect(ExportFormat.ply.fileExtension == "ply")
        #expect(ExportFormat.step.fileExtension == "step")
        #expect(ExportFormat.brep.fileExtension == "brep")
        #expect(ExportFormat.allCases.count == 4)
    }

    @Test func t_exportBoxToOBJ() async throws {
        guard let box = Shape.box(width: 2, height: 2, depth: 2) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let url = Self.tempURL(suffix: "box.obj")
        defer { try? FileManager.default.removeItem(at: url) }

        try await ExportManager.export(shapes: [box], format: .obj, to: url)

        #expect(FileManager.default.fileExists(atPath: url.path))
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = attrs[.size] as? Int ?? 0
        #expect(size > 0, "exported OBJ should be non-empty")
    }

    @Test func t_exportBoxToBREP() async throws {
        guard let box = Shape.box(width: 1, height: 1, depth: 1) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let url = Self.tempURL(suffix: "box.brep")
        defer { try? FileManager.default.removeItem(at: url) }

        try await ExportManager.export(shapes: [box], format: .brep, to: url)

        #expect(FileManager.default.fileExists(atPath: url.path))
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = attrs[.size] as? Int ?? 0
        #expect(size > 0)
    }

    @Test func t_exportMultipleShapesGetsNumberedFilenames() async throws {
        guard let a = Shape.box(width: 1, height: 1, depth: 1),
              let b = Shape.cylinder(radius: 1, height: 2)
        else {
            Issue.record("primitive constructors returned nil")
            return
        }
        let baseURL = Self.tempURL(suffix: "multi.step")
        defer {
            let dir = baseURL.deletingLastPathComponent()
            let prefix = baseURL.deletingPathExtension().lastPathComponent
            if let entries = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
                for entry in entries where entry.hasPrefix(prefix) {
                    try? FileManager.default.removeItem(atPath: dir.appendingPathComponent(entry).path)
                }
            }
        }

        try await ExportManager.export(shapes: [a, b], format: .step, to: baseURL)

        // ExportManager should produce <base>.0.step and <base>.1.step
        let base = baseURL.deletingPathExtension()
        let f0 = base.appendingPathExtension("0.step")
        let f1 = base.appendingPathExtension("1.step")
        #expect(FileManager.default.fileExists(atPath: f0.path))
        #expect(FileManager.default.fileExists(atPath: f1.path))
    }

    @Test func t_exportEmptyShapeListIsNoOp() async throws {
        let url = Self.tempURL(suffix: "empty.obj")
        defer { try? FileManager.default.removeItem(at: url) }

        try await ExportManager.export(shapes: [], format: .obj, to: url)

        #expect(!FileManager.default.fileExists(atPath: url.path),
                "empty input should not write a file")
    }
}
