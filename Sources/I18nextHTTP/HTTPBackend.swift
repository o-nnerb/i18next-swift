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
///
/// With `saveMissing`, keys `t` could not find are sent to `addPath` (see ``create(languages:namespace:key:fallbackValue:isUpdate:)``).
public struct HTTPBackend: Backend {
    /// Scheme and authority (`host[:port]`) plus an optional path prefix, e.g. `https://cdn.example.com/app`.
    public let baseURL: String
    /// Relative to `baseURL`. `{{lng}}` and `{{ns}}` are substituted in the path and in query values,
    /// e.g. `locales/{{lng}}/{{ns}}.json` or `i18n/{{ns}}.json?lng={{lng}}`.
    public let loadPath: String
    /// Where missing keys are posted, relative to `baseURL`, with `{{lng}}` and `{{ns}}` substituted as in
    /// ``loadPath``. `nil` turns sending off.
    public let addPath: String?
    public let headers: [String: String]
    /// Applied to connecting and reading.
    public let timeoutSeconds: Int

    private let scheme: URLScheme
    private let host: String
    private let pathPrefix: String

    public init(
        baseURL: String,
        loadPath: String = "locales/{{lng}}/{{ns}}.json",
        addPath: String? = "locales/add/{{lng}}/{{ns}}",
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
        self.addPath = addPath
        self.headers = headers
        self.timeoutSeconds = timeoutSeconds
        self.host = authority
        self.pathPrefix = String(rest[authorityEnd...]).trimmingSlashes()
    }

    public func read(language: String, namespace: String) async throws -> JSONValue {
        for component in [language, namespace] where !BackendError.isSafePathComponent(component) {
            throw BackendError.invalidKey(component)
        }

        let result = try await send(template: loadPath, language: language, namespace: namespace, payload: nil)

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

    /// Posts a missing key to ``addPath`` once per language, as `{"<key>": "<fallbackValue>"}` (an empty string when
    /// there is no fallback), like i18next-http-backend. Every language is attempted; if any request fails, the
    /// first failure (in language order) is thrown afterwards. `isUpdate` is not sent.
    ///
    /// Statuses follow ``read(language:namespace:)``: 2xx succeeds, 408/425/429/5xx and network errors are
    /// ``HTTPTransientError`` (not retried: the connector sends missing keys once), anything else is
    /// ``HTTPBackendError/unexpectedStatus(_:)``.
    public func create(
        languages: [String],
        namespace: String,
        key: String,
        fallbackValue: String?,
        isUpdate: Bool
    ) async throws {
        guard let addPath else { return }
        for component in languages + [namespace] where !BackendError.isSafePathComponent(component) {
            throw BackendError.invalidKey(component)
        }

        let payload = JSONValue.object([key: .string(fallbackValue ?? "")])
        let failures = await withTaskGroup(of: (Int, (any Error)?).self) { group in
            for (index, language) in languages.enumerated() {
                group.addTask {
                    do {
                        let result = try await send(
                            template: addPath,
                            language: language,
                            namespace: namespace,
                            payload: payload
                        )
                        let status = Int(result.head.status.code)
                        return (index, Self.failure(forCreateStatus: status))
                    } catch {
                        return (index, error)
                    }
                }
            }
            var collected: [(Int, any Error)] = []
            for await (index, error) in group {
                if let error { collected.append((index, error)) }
            }
            return collected
        }
        if let first = failures.min(by: { $0.0 < $1.0 }) { throw first.1 }
    }

    private static func failure(forCreateStatus status: Int) -> (any Error)? {
        switch status {
        case 200..<300: nil
        case 408, 425, 429, 500..<600: HTTPTransientError(statusCode: status, underlying: nil)
        default: HTTPBackendError.unexpectedStatus(status)
        }
    }

    // MARK: Internals

    /// Sends `payload` as a JSON `POST`, or a `GET` without one, to `template` expanded for the language and namespace.
    private func send(
        template: String,
        language: String,
        namespace: String,
        payload: JSONValue?
    ) async throws -> TaskResult<Data> {
        let (path, query) = Self.expand(template, language: language, namespace: namespace)
        let fullPath = [pathPrefix, path].filter { !$0.isEmpty }.joined(separator: "/")
        let queryItems = query.enumerated().map { RequestItem(id: $0.offset, name: $0.element.0, value: $0.element.1) }
        let headerItems = headers.sorted { $0.key < $1.key }
            .enumerated().map { RequestItem(id: $0.offset, name: $0.element.key, value: $0.element.value) }
        let scheme = scheme
        let host = host
        let timeout = Int64(timeoutSeconds)

        do {
            return try await DataTask {
                BaseURL(scheme, host: host)
                Path(fullPath)
                PropertyForEach(queryItems, id: \.id) { Query(name: $0.name, value: $0.value) }
                AcceptHeader(.json)
                PropertyForEach(headerItems, id: \.id) { CustomHeader(name: $0.name, value: $0.value) }
                if let payload {
                    RequestMethod(.post)
                    Payload(payload)
                }
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
    }

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
        Self.expand(loadPath, language: language, namespace: namespace)
    }

    func expandedAddPath(language: String, namespace: String) -> (path: String, query: [(String, String)]) {
        Self.expand(addPath ?? "", language: language, namespace: namespace)
    }

    static func expand(
        _ template: String,
        language: String,
        namespace: String
    ) -> (path: String, query: [(String, String)]) {
        func expand(_ text: String) -> String {
            text.splitKeepingEmpty(on: "{{lng}}").joined(separator: language)
                .splitKeepingEmpty(on: "{{ns}}").joined(separator: namespace)
        }

        let parts = template.splitKeepingEmpty(on: "?")
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
