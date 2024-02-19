import Foundation
import ArgumentParser
import SwiftParser

public struct Command: AsyncParsableCommand {
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
}

extension Command {
    private func processDirectory(at path: String, ignoringFolders: [String]) async {
        print("📦 Preparing ...")
        let directoryURL = URL(fileURLWithPath: path)
        
        print("📦 Collecting protocol types ...")
        await iterate(through: directoryURL, ignoringFolders: ignoringFolders) { fileURL in
                let sourceText = try String(contentsOf: fileURL)
                let sourceFile = Parser.parse(source: sourceText)
                let visitor = ProtocolVisitor(viewMode: .sourceAccurate)
                visitor.walk(sourceFile)
            }

        print("📦 Migration ...")
        var start: CFAbsoluteTime?
        await iterate(
            through: directoryURL,
            ignoringFolders: ignoringFolders,
            willStart: {
                if start == nil {
                    start = CFAbsoluteTimeGetCurrent()
                }
            }) { fileURL in
                print("✅ Updating \(fileURL.lastPathComponent)")
                let sourceText = try String(contentsOf: fileURL)
                let sourceFile = Parser.parse(source: sourceText)
                
                let modifiedSource = MyRewriter().visit(sourceFile)
                
                try modifiedSource
                    .description
                    .write(to: fileURL, atomically: true, encoding: .utf8)
            }
        if let start {
            let end = CFAbsoluteTimeGetCurrent()
            print("✅ Complete in \(end - start) sec.")
        }
    }
    
    private func iterate(
        through directoryURL: URL,
        ignoringFolders: [String],
        willStart: (() -> Void)? = nil,
        perform: @escaping (URL) throws -> Void
    ) async {
        let fileManager = FileManager.default
        let options: FileManager.DirectoryEnumerationOptions = [
            .skipsHiddenFiles,
            .skipsPackageDescendants
        ]
        
        await withThrowingTaskGroup(of: Void.self) { group in
            if let enumerator = fileManager.enumerator(
                at: directoryURL,
                includingPropertiesForKeys: nil,
                options: options
            ) {
                willStart?()
                for case let fileURL as URL in enumerator {
                    group.addTask {
                        do {
                            if fileURL.hasDirectoryPath {
                                return  // Skip directories, only want files
                            }
                            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                            if resourceValues.isDirectory == true {
                                if ignoringFolders.contains(fileURL.lastPathComponent) {
                                    // Skip this directory and its subdirectories
                                    enumerator.skipDescendants()
                                    return
                                }
                            }
                            // Check if the file is a Swift file
                            try Task.checkCancellation()
                            if fileURL.path.hasSuffix(".swift") {
                                try perform(fileURL)
                            }
                        } catch {
                            print(
                                "Error reading contents of directory \(fileURL.path): \(error)"
                            )
                            return
                        }
                    }
                }
            }
        }
    }
}
