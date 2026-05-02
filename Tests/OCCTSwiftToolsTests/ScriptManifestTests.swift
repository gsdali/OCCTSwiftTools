import Testing
import Foundation
import simd
@testable import OCCTSwiftTools

@Suite("ScriptManifest")
struct ScriptManifestTests {

    @Test func t_decodeRoundTripWithColorArray() throws {
        let json = """
        {
          "version": 1,
          "timestamp": "2026-05-03T12:00:00Z",
          "description": "test",
          "bodies": [
            {
              "id": "body0",
              "file": "body0.brep",
              "format": "brep",
              "name": "Box",
              "color": [0.2, 0.4, 0.6, 1.0],
              "roughness": 0.5,
              "metallic": 0.0
            }
          ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(ScriptManifest.self, from: json)

        #expect(manifest.version == 1)
        #expect(manifest.bodies.count == 1)
        let body = manifest.bodies[0]
        #expect(body.id == "body0")
        #expect(body.file == "body0.brep")
        #expect(body.format == "brep")
        #expect(body.name == "Box")
        if let color = body.color {
            #expect(color.x == 0.2)
            #expect(color.y == 0.4)
            #expect(color.z == 0.6)
            #expect(color.w == 1.0)
        } else {
            Issue.record("color should decode from [r,g,b,a] array")
        }
    }

    @Test func t_missingColorDecodesAsNil() throws {
        let json = """
        {
          "version": 1,
          "timestamp": "2026-05-03T12:00:00Z",
          "bodies": [
            { "file": "x.brep", "format": "brep" }
          ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(ScriptManifest.self, from: json)
        #expect(manifest.bodies[0].color == nil)
        #expect(manifest.bodies[0].id == nil)
    }

    @Test func t_metadataDecodes() throws {
        let json = """
        {
          "version": 1,
          "timestamp": "2026-05-03T12:00:00Z",
          "bodies": [],
          "metadata": {
            "name": "Sample Assembly",
            "revision": "A",
            "tags": ["mech", "demo"]
          }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(ScriptManifest.self, from: json)

        if let meta = manifest.metadata {
            #expect(meta.name == "Sample Assembly")
            #expect(meta.revision == "A")
            #expect(meta.tags == ["mech", "demo"])
        } else {
            Issue.record("manifest.metadata should decode")
        }
    }
}
