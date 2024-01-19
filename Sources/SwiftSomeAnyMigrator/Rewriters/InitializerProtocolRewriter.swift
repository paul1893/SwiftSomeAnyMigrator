import Foundation
import SwiftSyntax
import SwiftParser

final class InitializerProtocolRewriter: SyntaxRewriter {
    override func visit(_ node: InitializerDeclSyntax) -> DeclSyntax {
        return DeclSyntax(
            node.with(
                \.signature.parameterClause.parameters,
                 node.signature.parameterClause.parameters.applySomeOrAny()
            )
        )
    }
}
