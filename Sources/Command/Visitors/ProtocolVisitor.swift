import SwiftSyntax

actor Collector {
    static var protocols = Set<TokenSyntax>()
}

final class ProtocolVisitor: SyntaxVisitor {
    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        // Collect protocol
        Collector.protocols.insert(node.name)
        // No need to visit children, protocols can't contain other protocols
        return .skipChildren
    }
}
