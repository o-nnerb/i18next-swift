// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

import I18next
import RequestDL

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Loads bundles over HTTP with [RequestDL](https://github.com/request-dl/request-dl-nio).
///
/// The transport is fixed per platform: `URLSession` on Apple platforms, SwiftNIO everywhere else.
///
/// ```swift
/// options.backend = try HTTPBackend(baseURL: "https://cdn.example.com/app")
/// // GET https://cdn.example.com/app/locales/pt/translation.json
/// ```
///
/// Status handling: 2xx is parsed as JSON; 404 and 410 are `BackendError.notFound(language:namespace:)`;
/// 408, 425, 429 and 5xx, plus network failures, are ``HTTPTransientError`` (retried by the connector);
/// anything else is final.
public struct HTTPBackend: Backend {
    /// Scheme and authority (`host[:port]`) plus an optional path prefix, e.g. `https://cdn.example.com/app`.
    public let baseURL: String
    /// Relative to `baseURL`. `{{lng}}` and `{{ns}}` are substituted in the path and in query values,
    /// e.g. `locales/{{lng}}/{{ns}}.json` or `i18n/{{ns}}.json?lng={{lng}}`.
    public let loadPath: String
    public let headers: [String: String]
    /// Applied to connecting and reading.
    public let timeoutSeconds: Int

    private let scheme: URLScheme
    private let host: String
    private let pathPrefix: String

    public init(
        baseURL: String,
        loadPath: String = "locales/{{lng}}/{{ns}}.json",
        headers: [String: String] = [:],
        timeoutSeconds: Int = 10
    ) throws(HTTPBackendError) {
        guard timeoutSeconds > 0 else { throw .invalidConfiguration("timeoutSeconds must be positive") }

        let rest: Substring
        if baseURL.hasPrefix("https://") {
            scheme = .https
            rest = baseURL.dropFirst("https://".count)
        } else if baseURL.hasPrefix("http://") {
            scheme = .http
            rest = baseURL.dropFirst("http://".count)
        } else {
            throw .invalidBaseURL(baseURL)
        }
        guard !rest.contains("?"), !rest.contains("#") else { throw .invalidBaseURL(baseURL) }

        let authorityEnd = rest.firstIndex(of: "/") ?? rest.endIndex
        let authority = String(rest[..<authorityEnd])
        guard !authority.isEmpty else { throw .invalidBaseURL(baseURL) }

        self.baseURL = baseURL
        self.loadPath = loadPath
        self.headers = headers
        self.timeoutSeconds = timeoutSeconds
        self.host = authority
        self.pathPrefix = String(rest[authorityEnd...]).trimmingSlashes()
    }

    public func read(language: String, namespace: String) async throws -> JSONValue {
        for component in [language, namespace] where !BackendError.isSafePathComponent(component) {
            throw BackendError.invalidKey(component)
        }

        let (path, query) = expandedLoadPath(language: language, namespace: namespace)
        let fullPath = [pathPrefix, path].filter { !$0.isEmpty }.joined(separator: "/")
        let queryItems = query.enumerated().map { RequestItem(id: $0.offset, name: $0.element.0, value: $0.element.1) }
        let headerItems = headers.sorted { $0.key < $1.key }
            .enumerated().map { RequestItem(id: $0.offset, name: $0.element.key, value: $0.element.value) }
        let scheme = scheme
        let host = host
        let timeout = Int64(timeoutSeconds)

        let result: TaskResult<Data>
        do {
            result = try await DataTask {
                BaseURL(scheme, host: host)
                Path(fullPath)
                PropertyForEach(queryItems, id: \.id) { Query(name: $0.name, value: $0.value) }
                AcceptHeader(.json)
                PropertyForEach(headerItems, id: \.id) { CustomHeader(name: $0.name, value: $0.value) }
                Timeout(.seconds(timeout))
                Session().requiredExecutor(Self.executor)
            }
            .result()
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as BaseURLError {
            throw HTTPBackendError.invalidBaseURL("\(error)")
        } catch let error as ExecutorRequirementError {
            throw HTTPBackendError.invalidConfiguration("\(error)")
        } catch {
            throw HTTPTransientError(statusCode: nil, underlying: error)
        }

        let status = Int(result.head.status.code)
        switch status {
        case 200..<300:
            do {
                return try JSONValue(data: result.payload)
            } catch {
                throw HTTPBackendError.invalidResponse(language: language, namespace: namespace, underlying: error)
            }
        case 404, 410:
            throw BackendError.notFound(language: language, namespace: namespace)
        case 408, 425, 429, 500..<600:
            throw HTTPTransientError(statusCode: status, underlying: nil)
        default:
            throw HTTPBackendError.unexpectedStatus(status)
        }
    }

    // MARK: Internals

    /// The only transport per platform: `URLSession` on Apple, SwiftNIO elsewhere.
    private static var executor: Session.Executor {
        #if canImport(Darwin)
        .urlSession
        #else
        .nio
        #endif
    }

    private struct RequestItem: Sendable {
        let id: Int
        let name: String
        let value: String
    }

    func expandedLoadPath(language: String, namespace: String) -> (path: String, query: [(String, String)]) {
        func expand(_ text: String) -> String {
            text.splitKeepingEmpty(on: "{{lng}}").joined(separator: language)
                .splitKeepingEmpty(on: "{{ns}}").joined(separator: namespace)
        }

        let parts = loadPath.splitKeepingEmpty(on: "?")
        let path = expand(parts[0]).trimmingSlashes()
        guard parts.count > 1 else { return (path, []) }

        let items = parts.dropFirst().joined(separator: "?").splitKeepingEmpty(on: "&").compactMap {
            pair -> (String, String)? in
            guard !pair.isEmpty else { return nil }
            let halves = pair.splitKeepingEmpty(on: "=")
            return (halves[0], expand(halves.dropFirst().joined(separator: "=")))
        }
        return (path, items)
    }
}

// MARK: - Errors

/// A failure worth retrying: a network error or a 408/425/429/5xx response.
public struct HTTPTransientError: RetryableBackendError, CustomStringConvertible {
    public let statusCode: Int?
    public let underlying: (any Error)?

    public var description: String {
        if let statusCode { return "HTTP \(statusCode)" }
        return "network error: \(underlying.map { "\($0)" } ?? "unknown")"
    }
}

public enum HTTPBackendError: Error, Sendable {
    case invalidBaseURL(String)
    case invalidConfiguration(String)
    case unexpectedStatus(Int)
    /// A 2xx response whose body is not JSON.
    case invalidResponse(language: String, namespace: String, underlying: any Error)
}

extension String {
    fileprivate func trimmingSlashes() -> String {
        var slice = Substring(self)
        while slice.first == "/" { slice = slice.dropFirst() }
        while slice.last == "/" { slice = slice.dropLast() }
        return String(slice)
    }
}
