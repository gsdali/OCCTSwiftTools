// ImportProgressClosure.swift
// OCCTSwiftTools
//
// Closure-based ergonomics on top of OCCTSwift's ImportProgress protocol.
// Lets callers pass `progress: ImportProgressClosure { fraction, step in ... }`
// instead of writing a one-shot subclass.

import OCCTSwift

/// Closure-backed `ImportProgress` for one-shot use sites.
///
/// `progress` callbacks fire on whatever thread the importer runs on
/// (typically a background thread when the import is launched via the
/// async `CADFileLoader.load(from:format:progress:)` API). UI updates
/// must hop to the main actor explicitly.
///
/// ```swift
/// let result = try await CADFileLoader.load(
///     from: url, format: .step,
///     progress: ImportProgressClosure(
///         cancelCheck: { Task.isCancelled },
///         progress: { fraction, step in
///             Task { @MainActor in progressBar.setValue(fraction) }
///         }
///     )
/// )
/// ```
public final class ImportProgressClosure: ImportProgress, @unchecked Sendable {

    private let progressHandler: @Sendable (Double, String) -> Void
    private let cancelCheck: @Sendable () -> Bool

    /// - Parameters:
    ///   - cancelCheck: returns `true` to cooperatively cancel the import.
    ///     Defaults to `{ false }`. Common pattern: `{ Task.isCancelled }`
    ///     to wire upstream cancellation to a Swift `Task`.
    ///   - progress: called with `fraction` in `0.0...1.0` and a
    ///     human-readable step name (e.g. "Reading STEP file").
    public init(
        cancelCheck: @escaping @Sendable () -> Bool = { false },
        progress: @escaping @Sendable (Double, String) -> Void
    ) {
        self.cancelCheck = cancelCheck
        self.progressHandler = progress
    }

    public func progress(fraction: Double, step: String) {
        progressHandler(fraction, step)
    }

    public func shouldCancel() -> Bool { cancelCheck() }
}
