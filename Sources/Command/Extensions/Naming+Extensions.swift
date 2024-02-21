import SwiftSyntax

extension InitializerClauseSyntax {
    var hasDefaultValueWithSingleton: Bool {
        trimmedDescription.contains(".shared.") == true
    }
}

extension TokenSyntax {
    var isProtocol: Bool {
        self.text.isProtocolName
    }
}

extension TypeSyntax {
    var isProtocol: Bool {
        self.trimmedDescription.isProtocolName
    }
}

extension String {
    var isProtocolName: Bool {
        return Collector.shared.protocols.contains(where: {
            $0.trimmedDescription == self
        })
    }
}
