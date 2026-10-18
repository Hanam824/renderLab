/// The test scene: two overlapping triangles, chosen so every toggle has a visible effect.
///
/// - Blue is nearer (z = 0.3) but drawn first; red is farther (z = 0.6) and drawn second.
///   Depth test ON: blue stays in front. OFF: red paints over blue (draw order wins).
/// - Blue is wound counter-clockwise (front face), red clockwise (back face).
///   Cull back faces: red disappears. Cull front faces: blue disappears.
enum Scene {
    /// Interleaved vertex layout: position (x, y, z) followed by color (r, g, b).
    static let floatsPerVertex = 6
    static let vertexStride = floatsPerVertex * MemoryLayout<Float>.stride
    static let colorOffset = 3 * MemoryLayout<Float>.stride

    static let vertices: [Float] = [
        // Blue, near, counter-clockwise
        -0.6, -0.4, 0.3,   0.20, 0.45, 1.00,
         0.4, -0.4, 0.3,   0.20, 0.45, 1.00,
        -0.1,  0.6, 0.3,   0.55, 0.75, 1.00,
        // Red, far, clockwise
        -0.4,  0.4, 0.6,   1.00, 0.30, 0.25,
         0.6,  0.4, 0.6,   1.00, 0.30, 0.25,
         0.1, -0.6, 0.6,   1.00, 0.65, 0.30,
    ]

    static var vertexCount: Int { vertices.count / floatsPerVertex }
}
