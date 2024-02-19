import Foundation
import SwiftSyntax
import SwiftParser

extension SomeOrAnyTypeSyntax {
    func apply(_ keyword: Keyword) -> TypeSyntax {
        if let identifierType = self.constraint.as(IdentifierTypeSyntax.self) {
            return identifierType.apply(keyword)
        } else if let optionalType = self.constraint.as(OptionalTypeSyntax.self) {
            return optionalType.apply(keyword)
        } else {
            return TypeSyntax(self)
        }
    }
}

extension IdentifierTypeSyntax {
    func apply(_ keyword: Keyword) -> TypeSyntax {
        if name.isProtocol {
            return TypeSyntax(
                SomeOrAnyTypeSyntax(
                    someOrAnySpecifier: .keyword(keyword),
                    constraint:
                        IdentifierTypeSyntax(
                            leadingTrivia: .space,
                            name: .identifier(trimmedDescription),
                            trailingTrivia: trailingTrivia
                        )
                )
            )
        } else {
            return TypeSyntax(
                self.with(
                    \.genericArgumentClause,
                     genericArgumentClause?.apply(.any)
                )
            )
        }
    }
}

extension OptionalTypeSyntax {
    func apply(_ keyword: Keyword) -> TypeSyntax {
        let typeName = if let tupleType = wrappedType.as(TupleTypeSyntax.self), tupleType.elements.count == 1,
        let identifierTypeSyntax = tupleType
            .elements
            .first?
            .type
            .as(SomeOrAnyTypeSyntax.self)?
            .constraint
            .as(IdentifierTypeSyntax.self)
        {
            identifierTypeSyntax.name.text
        } else {
            wrappedType.trimmedDescription
        }
        
        if let tupleType = wrappedType.as(TupleTypeSyntax.self) {
            return TypeSyntax(
                self.with(
                    \.wrappedType,
                     TypeSyntax(tupleType.with(
                        \.elements,
                         tupleType.elements.apply(.any)
                     ))
                )
            )
        } else if typeName.isProtocolName {
            return TypeSyntax(
                SomeOrAnyTypeSyntax(
                    leadingTrivia: .unexpectedText("("),
                    someOrAnySpecifier: .keyword(/*policy == .strict ? .some : .any*/.any), // TODO PBA: Keep this optimization rule 🤔 ?
                    constraint:
                        OptionalTypeSyntax(
                            wrappedType: IdentifierTypeSyntax(
                                leadingTrivia: .space,
                                name: .identifier(typeName),
                                trailingTrivia: .unexpectedText(")")
                            )
                        ),
                    trailingTrivia: trailingTrivia
                )
            )
        } else {
            return TypeSyntax(self)
        }
    }
}

extension FunctionTypeSyntax {
    func apply(_ keyword: Keyword) -> Self {
        self
            .with(
                \.parameters,
                 TupleTypeElementListSyntax(
                    parameters.map {
                        return $0.with(
                            \.type,
                             $0.type.apply(keyword)
                        )
                    }
                 )
            )
            .with(
                \.returnClause,
                 returnClause.apply(.any)
            )
    }
}

extension TupleTypeElementListSyntax {
    func apply(
        _ keyword: Keyword
    ) -> Self {
        TupleTypeElementListSyntax(
            self.map {
                $0.with(
                    \.type,
                     $0.type.apply(keyword)
                )
            }
        )
    }
}

extension ReturnClauseSyntax {
    func applySomeOrAny(for policy: Policy) -> Self {
        let keyword: Keyword = policy == .strict ? .some : .any
        return self.with(
            \.type,
             self.type.apply(keyword)
        )
    }

    func apply(
        _ keyword: Keyword
    ) -> Self {
        self.with(
            \.type,
             self.type.apply(keyword)
        )
    }
}

extension TypeSyntax {
    func apply(_ keyword: Keyword, computedVar: Bool = false) -> Self {
        if let identifierTypeSyntax = self.as(IdentifierTypeSyntax.self) {
            return identifierTypeSyntax.apply(keyword)
        } else if let optionalTypeSyntax = self.as(OptionalTypeSyntax.self) {
            return optionalTypeSyntax.apply(keyword)
        } else if let someOrAnyTypeSyntax = self.as(SomeOrAnyTypeSyntax.self) {
            // Check if type already have `some` or `any` keyword in case of conservative policy
            if Metadata.conservative || computedVar {
                return self
            } else {
                return someOrAnyTypeSyntax.apply(keyword)
            }
        } else if let functionTypeSyntax = self.as(FunctionTypeSyntax.self) {
            return TypeSyntax(
                functionTypeSyntax.apply(keyword)
            )
        }
        else {
            return self
        }
    }
}


extension FunctionParameterListSyntax {
    func applySomeOrAny(for policy: Policy) -> Self {
        return Self(
            map { parameter -> FunctionParameterSyntax in
                let keyword: Keyword = if  parameter.defaultValue?.hasDefaultValueWithSingleton == true {
                    .any
                } else {
                    policy == .strict ? .some : .any
                }
                return parameter.with(
                    \.type,
                     parameter.type.apply(keyword)
                )
            }
        )
    }
}

extension VariableDeclSyntax {
    func apply(_ keyword: Keyword) -> Self {
        self.with(
            \.bindings,
             PatternBindingListSyntax(
                self.bindings.map { binding in
                    return binding.with(
                        \.typeAnnotation,
                         binding.typeAnnotation?.with(
                            \.type,
                             binding.typeAnnotation?.type.apply(keyword, computedVar: binding.accessorBlock != nil)
                         )
                    )
                }
             )
        )
    }
}

extension GenericArgumentClauseSyntax {
    func apply(_ keyword: Keyword) -> Self {
        if let genericArgumentListSyntax = self
            .arguments
            .as(GenericArgumentListSyntax.self) {
            return self.with(
                \.arguments,
                 GenericArgumentListSyntax(
                    genericArgumentListSyntax.map {
                        if let argument = $0
                            .as(GenericArgumentSyntax.self)?
                            .argument
                        {
                            return $0.with(
                                \.argument,
                                 argument.apply(keyword)
                            )
                        } else {
                            return $0
                        }
                    }
                 )
            )
        } else {
            return self
        }
    }
}
