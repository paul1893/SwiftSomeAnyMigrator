import Foundation
import SwiftSyntax

class Collector {
    static let shared = Collector()
    private init() {}

    private(set) var protocols = Set<TokenSyntax>()
    private let lock = NSRecursiveLock()

    func insert(_ node: TokenSyntax) {
        lock.lock()
        protocols.insert(node)
        lock.unlock()
    }
}

final class ProtocolVisitor: SyntaxVisitor {
    private let perform: (TokenSyntax) -> Void

    init(
        viewMode: SyntaxTreeViewMode,
        perform: @escaping (TokenSyntax) -> Void
    ) {
        self.perform = perform
        super.init(viewMode: viewMode)
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        perform(node.name)
        // No need to visit children, protocols can't contain other protocols
        return .skipChildren
    }
}
