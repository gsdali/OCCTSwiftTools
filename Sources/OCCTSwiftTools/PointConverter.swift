// PointConverter.swift
// OCCTSwiftTools
//
// Converts a raw point cloud (`[SIMD3<Float>]`) to a point-only `ViewportBody`
// for rendering. Sibling to `CurveConverter` / `SurfaceConverter` /
// `WireConverter` — keeps the "given X domain object, produce a ViewportBody"
// layering consistent.
//
// The body produced has empty `vertexData` / `indices` / `edges`. Its
// `vertices` carry the cloud points; the renderer is expected to interpret
// them as point primitives. The Metal point-rendering pipeline itself is
// renderer-side work tracked separately on OCCTSwiftViewport.

import simd
import OCCTSwiftViewport

/// Converts raw point clouds to point-only `ViewportBody` values.
public enum PointConverter {

    /// Build a `ViewportBody` whose `vertices` carry the input point cloud
    /// for renderer-side point rendering (no triangulation, no wireframe).
    ///
    /// Returns `nil` if `perPointColors` is non-nil and its length doesn't
    /// match `points.count` (length validation). Empty input is valid and
    /// returns an empty body — useful for clearing a prior point set without
    /// removing the body itself.
    ///
    /// - Parameters:
    ///   - points: point positions, in viewport-space coordinates
    ///   - id: stable id for the body
    ///   - color: fallback color used when the renderer doesn't sample
    ///     `perPointColors`. RGBA, defaults to a soft amber.
    ///   - pointRadius: intended on-screen radius (in world units) for each
    ///     point. The current renderer ignores this; wiring it up is renderer-
    ///     side work tracked on the OCCTSwiftViewport side.
    ///   - perPointColors: optional per-point colors. Must match `points.count`
    ///     when non-nil. The current renderer doesn't sample these (no
    ///     `vertexColors` field on `ViewportBody` yet); accepted here so the
    ///     API doesn't have to change when the renderer-side ticket lands.
    public static func pointsToBody(
        _ points: [SIMD3<Float>],
        id: String,
        color: SIMD4<Float> = SIMD4<Float>(1.0, 0.85, 0.2, 1.0),
        pointRadius: Float = 0.05,
        perPointColors: [SIMD4<Float>]? = nil
    ) -> ViewportBody? {
        if let perPointColors, perPointColors.count != points.count {
            return nil
        }
        _ = pointRadius // accepted for forward-compat; renderer wiring tracked separately
        return ViewportBody(
            id: id,
            vertexData: [],
            indices: [],
            edges: [],
            vertices: points,
            color: color
        )
    }
}
