import Foundation
import ArgumentParser
import SwiftParser

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
public struct SwiftSomeAnyMigratorCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        abstract: "A Swift command-line tool to add `any` and/or `some` keywords at needed locations in your codebase for Swift 6 compatibility",
        subcommands: []
    )

    @Argument(
        help: "Path to the project to migrate"
    )
    private var projectPath: String

    @Option(
        name: .shortAndLong,
        help: "List of folders to ignore (i.e:  Generated)"
    )
    private var ignoreFolders = [String]()

    @Option(
        name: .shortAndLong,
        help: "Policy to apply during migration"
    )
    private var policy = Metadata.policy

    @Flag(help: "Conservative will keep any or some keyword encountered in your codebase without trying to optimize")
    private var conservative = Metadata.conservative

    public init() {}

    public func run() async throws {
        Metadata.policy = policy
        Metadata.conservative = conservative

        await processDirectory(
            at: projectPath,
            ignoringFolders: ignoreFolders
        )
    }

    private func processDirectory(at path: String, ignoringFolders: [String]) async {
        print("📦 Preparing ...")
        let directoryURL = URL(fileURLWithPath: path)

        let fileManager = FileManager.default
        let options: FileManager.DirectoryEnumerationOptions = [
            .skipsHiddenFiles,
            .skipsPackageDescendants
        ]

        print("📦 Looking for files ...")
        var start: CFAbsoluteTime?
        await withThrowingTaskGroup(of: Void.self) { group in
            if let enumerator = fileManager.enumerator(at: directoryURL, includingPropertiesForKeys: nil, options: options) {
                for case let fileURL as URL in enumerator {
                    if start == nil { start = CFAbsoluteTimeGetCurrent() }
                    group.addTask {
                        do {
                            if fileURL.hasDirectoryPath {
                                return  // Skip directories, only want files
                            }
                            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                            if resourceValues.isDirectory == true {
                                if ignoringFolders.contains(fileURL.lastPathComponent) {
                                    enumerator.skipDescendants() // Skip this directory and its subdirectories
                                    return
                                }
                            }
                            // Check if the file is a Swift file
                            try Task.checkCancellation()
                            if fileURL.path.hasSuffix(".swift") {
                                print("✅ Updating \(fileURL.lastPathComponent)")
                                let sourceText = try String(contentsOf: fileURL)
                                let sourceFile = Parser.parse(source: sourceText)

                                var modifiedSource = sourceFile
                                let variableRewriter = GlobalVariableProtocolRewriter()
                                modifiedSource = variableRewriter.visit(modifiedSource)
                                let constructorRewriter = InitializerProtocolRewriter()
                                modifiedSource = constructorRewriter.visit(modifiedSource)

                                try modifiedSource
                                    .description
                                    .write(to: fileURL, atomically: true, encoding: .utf8)
                            }
                        } catch {
                            print("Error reading contents of directory \(fileURL.path): \(error)")
                            return
                        }
                    }
                }
            }
        }
        if let start {
            let end = CFAbsoluteTimeGetCurrent()
            print("✅ Complete in \(end - start) sec.")
        }
    }

}
