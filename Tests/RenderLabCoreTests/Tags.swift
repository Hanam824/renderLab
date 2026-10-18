import Testing

extension Tag {
    /// Needs a real GPU context. These tests skip themselves when none can be created.
    @Tag static var gpu: Self
}
