import Foundation
import SwiftSyntax
import SwiftParser

final class MyRewriter: SyntaxRewriter {
    // MARK: Initializer
    override func visit(_ node: InitializerDeclSyntax) -> DeclSyntax {
        return DeclSyntax(
            node.with(
                \.signature.parameterClause.parameters,
                 // Replace initializer parameters by some or any based on policy
                 node.signature.parameterClause.parameters
                    .applySomeOrAny(for: Metadata.policy)
            )
        )
    }

    // MARK: Functions
    override func visit(_ node: FunctionDeclSyntax) -> DeclSyntax {
        return DeclSyntax(
            node
                .with(
                    \.signature.parameterClause.parameters,
                     // Replace function parameters by some or any based on policy
                     node.signature.parameterClause.parameters
                        .applySomeOrAny(for: Metadata.policy)
                )
                .with(
                    \.signature.returnClause,
                     // Replace function return clause by some or any based on policy
                     node.signature.returnClause?
                        .applySomeOrAny(for: Metadata.policy)
                )
                .with(
                    \.body,
                     node.body?.with(
                        \.statements,
                         node.body.map { body in
                             let statements = body.statements.map { itemNode in
                                 // Replace var type in body function always by any
                                 if let variable = itemNode.item.as(VariableDeclSyntax.self) {
                                     let anyVariable = variable.apply(.any)
                                     return itemNode.with(
                                        \.item,
                                         CodeBlockItemSyntax.Item(anyVariable)
                                     )
                                 } else {
                                     return itemNode
                                 }
                             }
                             return CodeBlockItemListSyntax(statements)
                         }
                     )
                )
        )
    }
    
    // MARK: Variables
    override func visit(_ node: VariableDeclSyntax) -> DeclSyntax {
        // Replace var type always by any
        return DeclSyntax(node.apply(.any))
    }

    // MARK: TypeAlias
    override func visit(_ node: TypeAliasDeclSyntax) -> DeclSyntax {
        // Replace typealias type always by any
        return DeclSyntax(
            node.with(
                \.initializer.value,
                 node.initializer.value.apply(.any)
            )
        )
    }
}
