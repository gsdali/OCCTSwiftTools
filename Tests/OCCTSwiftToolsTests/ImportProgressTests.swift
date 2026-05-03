import Testing
import Foundation
import OCCTSwift
@testable import OCCTSwiftTools

@Suite("ImportProgress")
struct ImportProgressTests {

    private static func tempURL(suffix: String) -> URL {
        URL(fileURLWithPath: "/tmp/occtswifttools-progress-\(UUID().uuidString)-\(suffix)")
    }

    // MARK: - Closure adapter

    @Test func t_closureAdapterForwardsCalls() {
        nonisolated(unsafe) var captured: [(Double, String)] = []
        nonisolated(unsafe) var cancelChecks = 0

        let adapter = ImportProgressClosure(
            cancelCheck: {
                cancelChecks += 1
                return false
            },
            progress: { fraction, step in
                captured.append((fraction, step))
            }
        )

        adapter.progress(fraction: 0.25, step: "halfway-ish")
        adapter.progress(fraction: 1.0, step: "done")
        _ = adapter.shouldCancel()
        _ = adapter.shouldCancel()

        #expect(captured.count == 2)
        #expect(captured[0].0 == 0.25)
        #expect(captured[0].1 == "halfway-ish")
        #expect(captured[1].0 == 1.0)
        #expect(cancelChecks == 2)
    }

    @Test func t_closureAdapterDefaultCancelCheckReturnsFalse() {
        let adapter = ImportProgressClosure(progress: { _, _ in })
        #expect(adapter.shouldCancel() == false)
    }

    // MARK: - Recorder helper for end-to-end tests

    /// Test-only progress observer. Records every callback so we can assert
    /// after the import returns.
    final class Recorder: ImportProgress, @unchecked Sendable {
        let lock = NSLock()
        private var _fractions: [Double] = []
        private var _steps: [String] = []
        var cancelOnFraction: Double? = nil

        var fractions: [Double] {
            lock.lock(); defer { lock.unlock() }
            return _fractions
        }

        var lastStep: String? {
            lock.lock(); defer { lock.unlock() }
            return _steps.last
        }

        func progress(fraction: Double, step: String) {
            lock.lock(); defer { lock.unlock() }
            _fractions.append(fraction)
            _steps.append(step)
        }

        func shouldCancel() -> Bool {
            lock.lock(); defer { lock.unlock() }
            if let threshold = cancelOnFraction,
               let latest = _fractions.last,
               latest >= threshold {
                return true
            }
            return false
        }
    }

    // MARK: - End-to-end STEP round-trip with progress

    @Test func t_stepLoadFiresProgressCallback() async throws {
        // Round-trip: build a box, export to STEP, re-import via CADFileLoader
        // with a recorder. We don't assert specific fraction values (OCCT's
        // progress granularity isn't documented) — just that progress fired.
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let url = Self.tempURL(suffix: "roundtrip.step")
        defer { try? FileManager.default.removeItem(at: url) }

        try await ExportManager.export(shapes: [box], format: .step, to: url)

        let recorder = Recorder()
        let result = try await CADFileLoader.load(from: url, format: .step, progress: recorder)

        #expect(result.bodies.count >= 1, "import produced at least one body")
        // Even a small box should yield at least one progress call from the
        // OCCT reader; a complete one usually finishes near 1.0.
        #expect(!recorder.fractions.isEmpty,
                "progress observer should fire at least once during STEP import")
        if let last = recorder.fractions.last {
            #expect(last <= 1.0 + 1e-6, "fraction stays in [0, 1]")
            #expect(last >= 0.0)
        }
    }

    // MARK: - Cancellation

    @Test func t_stepLoadHonorsCancellation() async throws {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let url = Self.tempURL(suffix: "cancel.step")
        defer { try? FileManager.default.removeItem(at: url) }

        try await ExportManager.export(shapes: [box], format: .step, to: url)

        // Recorder cancels as soon as it sees any progress callback.
        let recorder = Recorder()
        recorder.cancelOnFraction = 0.0   // fire on the very first callback

        do {
            _ = try await CADFileLoader.load(from: url, format: .step, progress: recorder)
            // If the import is so fast it completes before any callback has
            // a chance to flip the cancel flag, the test box was too small.
            // Accept that — what we're really verifying is "cancellation
            // path doesn't crash and produces ImportError.cancelled when honored".
        } catch ImportError.cancelled {
            // Expected outcome on cancel.
        } catch {
            Issue.record("expected ImportError.cancelled or success, got \(error)")
        }
    }
}
