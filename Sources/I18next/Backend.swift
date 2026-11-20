// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

/// Source of translation resources, read one `(language, namespace)` bundle at a time.
///
/// Throw an error that also conforms to ``RetryableBackendError`` for transient failures
/// (network timeouts, 5xx); any other error is final for that bundle.
public protocol Backend: Sendable {
    func read(language: String, namespace: String) async throws -> JSONValue

    /// Stores a key that `t` could not find (`Options.saveMissing`). The default does nothing.
    func create(
        languages: [String],
        namespace: String,
        key: String,
        fallbackValue: String?,
        isUpdate: Bool
    ) async throws
}

extension Backend {
    public func create(
        languages: [String],
        namespace: String,
        key: String,
        fallbackValue: String?,
        isUpdate: Bool
    ) async throws {}
}

/// Marks a backend error as transient, so the connector retries the read with exponential back-off.
public protocol RetryableBackendError: Error {}

public enum BackendError: Error, Sendable, Equatable {
    case notFound(language: String, namespace: String)
    /// The language or namespace is not usable as a path component.
    case invalidKey(String)
}

extension BackendError {
    /// Languages and namespaces come from callers; backends that build paths from them must not let them
    /// climb out of their root (`../`) or add segments.
    package static func isSafePathComponent(_ value: String) -> Bool {
        !value.isEmpty
            && !value.contains("/")
            && !value.contains("\\")
            && value.indexRange(of: "..") == nil
    }
}

public struct BackendOptions: Sendable {
    /// Reads running at the same time.
    public var maxParallelReads = 10
    /// Extra attempts after the first for ``RetryableBackendError``s.
    public var maxRetries = 5
    /// First back-off; doubles after every retry.
    public var retryDelayMilliseconds = 350

    public init() {}
}

public struct ResourceKey: Sendable, Hashable, CustomStringConvertible {
    public let language: String
    public let namespace: String

    public init(language: String, namespace: String) {
        self.language = language
        self.namespace = namespace
    }

    public var description: String { "\(language)/\(namespace)" }
}

public struct LoadFailure: Sendable {
    public let key: ResourceKey
    public let error: any Error
}

/// Result of a load. Failures never abort the call: translation falls through to the other languages.
public struct LoadReport: Sendable {
    /// Bundles read from the backend by this call (or by a read it joined), sorted.
    public internal(set) var loaded: [ResourceKey] = []
    public internal(set) var failures: [LoadFailure] = []

    public var isComplete: Bool { failures.isEmpty }

    public init() {}
}

// MARK: - In-memory

/// Serves bundles from a dictionary. Mostly useful for tests and previews.
public struct InMemoryBackend: Backend {
    public var resources: ResourceStore.Resources

    public init(_ resources: ResourceStore.Resources) {
        self.resources = resources
    }

    public func read(language: String, namespace: String) async throws -> JSONValue {
        guard let bundle = resources[language]?[namespace] else {
            throw BackendError.notFound(language: language, namespace: namespace)
        }
        return bundle
    }
}
