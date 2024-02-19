import SwiftSyntax

extension SyntaxProtocol {
    func with<T>(_ keyPath: WritableKeyPath<Self, T>, _ value: T?) -> Self {
        var copy = self
        if let value {
            copy[keyPath: keyPath] = value
        }
        return copy
    }
}
