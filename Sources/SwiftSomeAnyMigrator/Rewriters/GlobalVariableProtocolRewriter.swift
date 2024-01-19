import Foundation
import SwiftSyntax
import SwiftParser

final class GlobalVariableProtocolRewriter: SyntaxRewriter {
    override func visit(_ node: VariableDeclSyntax) -> DeclSyntax {
        guard let binding = node.bindings.first,
              let index = node.bindings.index(of: binding),
              let nodeTypeAnnotation = binding.typeAnnotation
        else {
            return DeclSyntax(node)
        }

        let keyPath: WritableKeyPath<VariableDeclSyntax, TypeSyntax>? = if let _ = node.bindings.first?.typeAnnotation?.type {
            \VariableDeclSyntax.bindings[index].typeAnnotation!.type
        } else {
            nil
        }

        if let type = nodeTypeAnnotation.type.as(IdentifierTypeSyntax.self),
           let keyPath,
           type.name.isProtocol {
            return DeclSyntax(
                node.with(
                    keyPath,
                    TypeSyntax(
                        SomeOrAnyTypeSyntax(
                            someOrAnySpecifier: .keyword(.any),
                            constraint:
                                IdentifierTypeSyntax(
                                    leadingTrivia: .space,
                                    name: .identifier(type.name.text),
                                    trailingTrivia: type.trailingTrivia
                                )
                        )
                    )
                )
            )
        } else if let optionalType = nodeTypeAnnotation.type.as(OptionalTypeSyntax.self),
                  let type = optionalType.wrappedType.as(IdentifierTypeSyntax.self),
                  let keyPath,
                  type.name.isProtocol {
            return DeclSyntax(
                node.with(
                    keyPath,
                    TypeSyntax(
                        SomeOrAnyTypeSyntax(
                            leadingTrivia: .unexpectedText("("),
                            someOrAnySpecifier: .keyword(.any),
                            constraint:
                                OptionalTypeSyntax(
                                    wrappedType: IdentifierTypeSyntax(
                                        leadingTrivia: .space,
                                        name: .identifier(type.name.text),
                                        trailingTrivia: .unexpectedText(")")
                                    )
                                ),
                            trailingTrivia: optionalType.trailingTrivia
                        )
                    )
                )
            )
        } else {
            return DeclSyntax(node)
        }
    }
}
