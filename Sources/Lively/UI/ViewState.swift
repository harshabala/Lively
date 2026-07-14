import SwiftUI

/// Drop-in replacement for SwiftUI's `@State` macro that works with Command Line Tools.
///
/// Recent SDKs implement `@State` as an external macro (`SwiftUIMacros.StateMacro`),
/// which ships only with full Xcode. This wrapper stores a real `SwiftUI.State`
/// value as a `DynamicProperty` so views still participate in the update graph,
/// without requiring the macro plugin.
@propertyWrapper
public struct ViewState<Value>: DynamicProperty {
    private var storage: State<Value>

    public init(wrappedValue: Value) {
        storage = State(wrappedValue: wrappedValue)
    }

    public init(initialValue: Value) {
        storage = State(initialValue: initialValue)
    }

    public var wrappedValue: Value {
        get { storage.wrappedValue }
        nonmutating set { storage.wrappedValue = newValue }
    }

    public var projectedValue: Binding<Value> {
        storage.projectedValue
    }
}
