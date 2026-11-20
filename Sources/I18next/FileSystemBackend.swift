#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Reads `{{lng}}/{{ns}}.json` (configurable) from a directory.
public struct FileSystemBackend: Backend {
    public var directory: String
    /// Relative to `directory`; `{{lng}}` and `{{ns}}` are substituted.
    public var loadPath: String

    public init(directory: String, loadPath: String = "{{lng}}/{{ns}}.json") {
        self.directory = directory
        self.loadPath = loadPath
    }

    public func read(language: String, namespace: String) async throws -> JSONValue {
        for component in [language, namespace] where !BackendError.isSafePathComponent(component) {
            throw BackendError.invalidKey(component)
        }

        let relative =
            loadPath
            .splitKeepingEmpty(on: "{{lng}}").joined(separator: language)
            .splitKeepingEmpty(on: "{{ns}}").joined(separator: namespace)
        let path = directory.hasSuffix("/") ? directory + relative : directory + "/" + relative

        let data: Data
        do {
            data = try await Task.detached { try Data(contentsOf: URL(fileURLWithPath: path)) }.value
        } catch {
            throw BackendError.notFound(language: language, namespace: namespace)
        }
        return try JSONValue(data: data)
    }

}
