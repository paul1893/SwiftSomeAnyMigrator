import Foundation
import SwiftSyntax
import SwiftParser

extension IdentifierTypeSyntax {
    func applySomeOrAny(
        for policy: Policy,
        defaultValue: InitializerClauseSyntax?
    ) -> TypeSyntax {
        if defaultValue?.hasDefaultValueWithSingleton == true {
            return TypeSyntax(
                SomeOrAnyTypeSyntax(
                    someOrAnySpecifier: .keyword(.any),
                    constraint:
                        IdentifierTypeSyntax(
                            leadingTrivia: .space,
                            name: .identifier(description),
                            trailingTrivia: defaultValue != nil ? nil : trailingTrivia
                        )
                )
            )
        } else {
            return TypeSyntax(
                SomeOrAnyTypeSyntax(
                    someOrAnySpecifier: .keyword(policy == .strict ? .some : .any),
                    constraint:
                        IdentifierTypeSyntax(
                            leadingTrivia: .space,
                            name: .identifier(description),
                            trailingTrivia: defaultValue != nil ? nil : trailingTrivia
                        )
                )
            )
        }
    }
}

extension OptionalTypeSyntax {
    func applySomeOrAny(
        for policy: Policy,
        defaultValue: InitializerClauseSyntax?
    ) -> TypeSyntax {

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
            wrappedType.description
        }

        if defaultValue?.hasDefaultValueWithSingleton == true {
            return TypeSyntax(
                SomeOrAnyTypeSyntax(
                    leadingTrivia: .unexpectedText("("),
                    someOrAnySpecifier: .keyword(.any),
                    constraint:
                        OptionalTypeSyntax(
                            wrappedType: IdentifierTypeSyntax(
                                leadingTrivia: .space,
                                name: .identifier(typeName),
                                trailingTrivia: .unexpectedText(")")
                            )
                        ),
                    trailingTrivia: .space
                )
            )
        } else {
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
                    trailingTrivia: defaultValue != nil ? .space : trailingTrivia
                )
            )
        }
    }
}

extension SomeOrAnyTypeSyntax {
    func applySomeOrAny(
        for policy: Policy,
        defaultValue: InitializerClauseSyntax?
    ) -> TypeSyntax {
        if let identifierTypeSyntax = self.constraint.as(IdentifierTypeSyntax.self) {
            return identifierTypeSyntax.applySomeOrAny(
                for: policy,
                defaultValue: defaultValue
            )
        } else if let optionalTypeSyntax = self.constraint.as(OptionalTypeSyntax.self) {
            return optionalTypeSyntax.applySomeOrAny(
                for: policy,
                defaultValue: defaultValue
            )
        } else {
            return TypeSyntax(self)
        }
    }
}

extension FunctionParameterListSyntax {
    func applySomeOrAny() -> Self {
        let modifiedParameters = map { parameter -> FunctionParameterSyntax in

            let policy = Metadata.policy
            let typeSyntax = parameter.type
            // Check if any of the parameters are of type Protocol and does not already have `some` or `any` keyword in case of conservative policy
            let haveSomeOrAnyKeyword = Metadata.conservative 
            ? parameter.type.as(SomeOrAnyTypeSyntax.self) != nil
            : false
            guard typeSyntax.isProtocol,
                  !haveSomeOrAnyKeyword
            else {
                return parameter
            }

            if let identifierTypeSyntax = typeSyntax.as(IdentifierTypeSyntax.self) {
                return parameter.with(
                    \.type,
                     identifierTypeSyntax.applySomeOrAny(
                        for: policy,
                        defaultValue: parameter.defaultValue
                     )
                )
            } else if let optionalTypeSyntax = typeSyntax.as(OptionalTypeSyntax.self) {
                return parameter.with(
                    \.type,
                     optionalTypeSyntax.applySomeOrAny(
                        for: policy,
                        defaultValue: parameter.defaultValue
                     )
                )
            } else if let someOrAnyTypeSyntax = typeSyntax.as(SomeOrAnyTypeSyntax.self) {
                return parameter.with(
                    \.type,
                     someOrAnyTypeSyntax.applySomeOrAny(
                        for: policy,
                        defaultValue: parameter.defaultValue
                     )
                )
            } else {
                return parameter
            }
        }
        return Self(modifiedParameters)
    }
}

extension InitializerClauseSyntax {
    var hasDefaultValueWithSingleton: Bool {
        description.contains(".shared.") == true
    }
}

extension TokenSyntax {
    var isProtocol: Bool {
        self.text.isProtocolName
    }
}

extension TypeSyntax {
    var isProtocol: Bool {
        self.description.isProtocolName
    }
}

extension String {
    var isProtocolName: Bool {
        (self.contains("Protocol")
         || self.contains("Viewable")
         || self.contains("Interface")
         || self.contains("Delegate")
         || self.contains("Modelable")
        )
        && !self.description.contains("Mock")
        && self.description != "AppDelegate"
        && self.description != "SceneDelegate"
    }
}
