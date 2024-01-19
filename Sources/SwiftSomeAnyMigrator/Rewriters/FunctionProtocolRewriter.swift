import Foundation
import SwiftSyntax
import SwiftParser

final class FunctionProtocolRewriter: SyntaxRewriter {
    override func visit(_ node: FunctionDeclSyntax) -> DeclSyntax {
        return DeclSyntax(
            node.with(
                \.signature.parameterClause.parameters,
                 node.signature.parameterClause.parameters.applySomeOrAny()
            )
        )
    }
}
