import Foundation
import SwiftSomeAnyMigrator

@main
struct Root {
    static func main() async throws {
        await SwiftSomeAnyMigratorCommand.main()
    }
}
