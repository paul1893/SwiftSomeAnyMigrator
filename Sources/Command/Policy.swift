import ArgumentParser

enum Metadata {
    static var policy = Policy.strict
    static var conservative = false
}

public enum Policy: String, ExpressibleByArgument {
    case strict, light
    
    public init?(argument: String) {
        if let policy = Policy(rawValue: argument) {
            self = policy
        } else {
            return nil
        }
    }
}
