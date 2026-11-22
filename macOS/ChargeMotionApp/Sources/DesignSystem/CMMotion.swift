import SwiftUI

/// Animation presets. Motion answers an action or shows a change; nothing here
/// runs on its own.
enum CMMotion {
    static let quick = Animation.easeOut(duration: 0.14)
    static let hover = Animation.easeOut(duration: 0.18)
    static let standard = Animation.easeInOut(duration: 0.26)
    static let emphasized = Animation.spring(response: 0.42, dampingFraction: 0.86)
}

private struct CMAnimationModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: Value

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

extension View {
    /// Like `.animation(_:value:)`, but disabled when Reduce Motion is on.
    func cmAnimation<Value: Equatable>(_ animation: Animation = CMMotion.standard, value: Value) -> some View {
        modifier(CMAnimationModifier(animation: animation, value: value))
    }
}
