// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

import Foundation
import I18next
import Testing

@testable import I18nextHTTP

#if canImport(Darwin)
import Darwin

/// Minimal HTTP/1.1 server on a loopback socket: one request per connection, scripted responses.
final class TestServer: @unchecked Sendable {
    struct Request: Sendable {
        let method: String
        let target: String  // path and query as sent
        let headers: [String: String]  // lower-cased names
        let body: String
        var path: String { String(target.prefix { $0 != "?" }) }
    }
    struct Response: Sendable {
        var status = 200
        var body = "{}"
    }

    private let lock = NSLock()
    private var recorded: [Request] = []
    private let handler: @Sendable (Request, Int) -> Response  // request, 1-based count of requests to that path
    private var listener: Int32 = -1
    private(set) var port: UInt16 = 0

    init(handler: @escaping @Sendable (Request, Int) -> Response) throws {
        self.handler = handler

        listener = socket(AF_INET, SOCK_STREAM, 0)
        guard listener >= 0 else { throw POSIXError(.EIO) }
        var yes: Int32 = 1
        setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        address.sin_port = 0
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listener, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0, listen(listener, 64) == 0 else { throw POSIXError(.EADDRINUSE) }

        var assigned = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &assigned) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(listener, $0, &length) }
        }
        port = UInt16(bigEndian: assigned.sin_port)

        let fd = listener
        Thread.detachNewThread { [self] in
            while true {
                let client = accept(fd, nil, nil)
                if client < 0 { return }
                DispatchQueue.global().async { self.serve(client) }
            }
        }
    }

    var baseURL: String { "http://127.0.0.1:\(port)" }

    var requests: [Request] { lock.withLock { recorded } }
    func count(of path: String) -> Int { requests.filter { $0.path == path }.count }

    func stop() {
        shutdown(listener, SHUT_RDWR)
        close(listener)
    }

    private func serve(_ client: Int32) {
        defer { close(client) }
        var raw = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while raw.range(of: Data("\r\n\r\n".utf8)) == nil {
            let n = read(client, &buffer, buffer.count)
            if n <= 0 { return }
            raw.append(contentsOf: buffer[0..<n])
        }

        let separator = raw.range(of: Data("\r\n\r\n".utf8))!
        var bodyBytes = Data(raw[separator.upperBound...])
        let lines = String(decoding: raw[..<separator.lowerBound], as: UTF8.self).components(separatedBy: "\r\n")
        let startLine = lines[0].split(separator: " ")
        guard startLine.count >= 2 else { return }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            headers[line[..<colon].lowercased()] = line[line.index(after: colon)...].trimmingCharacters(
                in: .whitespaces
            )
        }

        let expected = headers["content-length"].flatMap { Int($0) } ?? 0
        while bodyBytes.count < expected {
            let n = read(client, &buffer, buffer.count)
            if n <= 0 { break }
            bodyBytes.append(contentsOf: buffer[0..<n])
        }

        let request = Request(
            method: String(startLine[0]),
            target: String(startLine[1]),
            headers: headers,
            body: String(decoding: bodyBytes, as: UTF8.self)
        )
        let seen = lock.withLock { () -> Int in
            recorded.append(request)
            return recorded.filter { $0.path == request.path }.count
        }
        let response = handler(request, seen)

        let body = Data(response.body.utf8)
        let head =
            "HTTP/1.1 \(response.status) X\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        let payload = Data(head.utf8) + body
        payload.withUnsafeBytes { bytes in
            var sent = 0
            while sent < bytes.count {
                let n = write(client, bytes.baseAddress!.advanced(by: sent), bytes.count - sent)
                if n <= 0 { return }
                sent += n
            }
        }
    }
}

private func ok(_ body: String) -> TestServer.Response { .init(status: 200, body: body) }

private func makeI18n(
    server: TestServer,
    lng: String = "pt",
    loadPath: String = "locales/{{lng}}/{{ns}}.json",
    headers: [String: String] = [:],
    configure: (inout I18next.Options) -> Void = { _ in }
) throws -> I18next {
    let backend = try HTTPBackend(baseURL: server.baseURL, loadPath: loadPath, headers: headers, timeoutSeconds: 5)
    return I18next { options in
        options.lng = lng
        options.fallbackLng = .none
        options.backend = backend
        options.backendOptions.retryDelayMilliseconds = 1
        configure(&options)
    }
}

@Suite("HTTPBackend over URLSession", .serialized)
struct HTTPBackendTests {
    @Test func loadsBundlesAndTranslates() async throws {
        let server = try TestServer { request, _ in
            switch request.path {
            case "/locales/pt/translation.json": ok(#"{"hello":"Olá","nested":{"a":"b"}}"#)
            case "/locales/pt/common.json": ok(#"{"ok":"Certo"}"#)
            default: .init(status: 404, body: "{}")
            }
        }
        defer { server.stop() }

        let i18n = try makeI18n(server: server) { $0.ns = ["translation", "common"] }
        let report = await i18n.initialize()

        #expect(report.isComplete)
        #expect(i18n.t("hello") == "Olá")
        #expect(i18n.t("nested.a") == "b")
        #expect(i18n.t("common:ok") == "Certo")
    }

    @Test func sendsAcceptAndCustomHeaders() async throws {
        let server = try TestServer { _, _ in ok(#"{"k":"v"}"#) }
        defer { server.stop() }

        let i18n = try makeI18n(server: server, headers: ["X-Api-Key": "secret"])
        await i18n.initialize()

        let request = try #require(server.requests.first)
        #expect(request.headers["x-api-key"] == "secret")
        #expect(request.headers["accept"]?.contains("application/json") == true)
        #expect(i18n.t("k") == "v")
    }

    @Test func notFoundIsFinalAndNotRetried() async throws {
        let server = try TestServer { _, _ in .init(status: 404, body: "nope") }
        defer { server.stop() }

        let report = await (try makeI18n(server: server)).initialize()

        #expect(report.failures.count == 1)
        #expect(report.failures.first?.error as? BackendError == .notFound(language: "pt", namespace: "translation"))
        #expect(server.count(of: "/locales/pt/translation.json") == 1)
    }

    @Test func serverErrorsAreRetriedUntilSuccess() async throws {
        let server = try TestServer { _, attempt in attempt < 3 ? .init(status: 503, body: "") : ok(#"{"hello":"Olá"}"#)
        }
        defer { server.stop() }

        let i18n = try makeI18n(server: server)
        let report = await i18n.initialize()

        #expect(report.isComplete)
        #expect(server.count(of: "/locales/pt/translation.json") == 3)
        #expect(i18n.t("hello") == "Olá")
    }

    @Test func persistentServerErrorsExhaustRetries() async throws {
        let server = try TestServer { _, _ in .init(status: 500, body: "") }
        defer { server.stop() }

        let i18n = try makeI18n(server: server) { $0.backendOptions.maxRetries = 2 }
        let report = await i18n.initialize()

        let failure = try #require(report.failures.first)
        #expect((failure.error as? HTTPTransientError)?.statusCode == 500)
        #expect(server.count(of: "/locales/pt/translation.json") == 3)
    }

    @Test func otherStatusesAreFinal() async throws {
        let server = try TestServer { _, _ in .init(status: 403, body: "") }
        defer { server.stop() }

        let report = await (try makeI18n(server: server)).initialize()

        guard case .unexpectedStatus(403)? = report.failures.first?.error as? HTTPBackendError else {
            Issue.record("expected unexpectedStatus(403), got \(String(describing: report.failures.first?.error))")
            return
        }
        #expect(server.count(of: "/locales/pt/translation.json") == 1)
    }

    @Test func invalidJSONIsFinal() async throws {
        let server = try TestServer { _, _ in ok("<html>not json</html>") }
        defer { server.stop() }

        let report = await (try makeI18n(server: server)).initialize()

        guard case .invalidResponse? = report.failures.first?.error as? HTTPBackendError else {
            Issue.record("expected invalidResponse, got \(String(describing: report.failures.first?.error))")
            return
        }
        #expect(server.count(of: "/locales/pt/translation.json") == 1)
    }

    @Test func connectionFailureIsTransient() async throws {
        let server = try TestServer { _, _ in ok("{}") }
        let url = server.baseURL
        server.stop()  // nothing listens on that port any more

        let backend = try HTTPBackend(baseURL: url, timeoutSeconds: 2)
        await #expect(throws: HTTPTransientError.self) {
            try await backend.read(language: "pt", namespace: "translation")
        }
    }

    @Test func loadPathSupportsPrefixAndQuery() async throws {
        let server = try TestServer { _, _ in ok(#"{"k":"v"}"#) }
        defer { server.stop() }

        let backend = try HTTPBackend(
            baseURL: server.baseURL + "/cdn/",
            loadPath: "/i18n/{{ns}}.json?lng={{lng}}&v=3",
            timeoutSeconds: 5
        )
        _ = try await backend.read(language: "pt-BR", namespace: "common")

        let request = try #require(server.requests.first)
        #expect(request.path == "/cdn/i18n/common.json")
        #expect(request.target.contains("lng=pt-BR"))
        #expect(request.target.contains("v=3"))
    }

    @Test func rejectsUnsafeLanguageAndNamespace() async throws {
        let server = try TestServer { _, _ in ok("{}") }
        defer { server.stop() }
        let backend = try HTTPBackend(baseURL: server.baseURL)

        for (language, namespace) in [("../x", "t"), ("pt", "a/b"), ("", "t"), ("pt", "..")] {
            await #expect(throws: BackendError.self) {
                try await backend.read(language: language, namespace: namespace)
            }
        }
        #expect(server.requests.isEmpty)
    }
}

@Suite("HTTPBackend create", .serialized)
struct HTTPBackendCreateTests {
    private func waitForPost(_ server: TestServer) async {
        for _ in 0..<500 where !server.requests.contains(where: { $0.method == "POST" }) {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    @Test func saveMissingPostsTheKeyToAddPath() async throws {
        let server = try TestServer { request, _ in
            request.method == "GET" ? ok(#"{"hello":"Olá"}"#) : ok("{}")
        }
        defer { server.stop() }

        let i18n = try makeI18n(server: server, headers: ["X-Api-Key": "secret"]) { $0.saveMissing = true }
        await i18n.initialize()
        #expect(i18n.t("novo", .init(defaultValue: "Novo")) == "Novo")
        await waitForPost(server)

        let post = try #require(server.requests.first { $0.method == "POST" })
        #expect(post.path == "/locales/add/pt/translation")
        #expect(post.headers["content-type"]?.hasPrefix("application/json") == true)
        #expect(post.headers["x-api-key"] == "secret")
        #expect(try JSONValue(json: post.body) == ["novo": "Novo"])
    }

    @Test func sendsAnEmptyStringWithoutAFallbackAndKeepsTheKeyAsIs() async throws {
        let server = try TestServer { _, _ in ok("{}") }
        defer { server.stop() }
        let backend = try HTTPBackend(baseURL: server.baseURL)

        try await backend.create(
            languages: ["pt"],
            namespace: "common",
            key: "a.b c",
            fallbackValue: nil,
            isUpdate: false
        )

        let post = try #require(server.requests.first)
        #expect(post.method == "POST")
        #expect(post.path == "/locales/add/pt/common")
        #expect(try JSONValue(json: post.body) == ["a.b c": ""])
    }

    @Test func postsOncePerLanguageAndAttemptsAllBeforeFailing() async throws {
        let server = try TestServer { request, _ in
            request.path.contains("/pt/") ? .init(status: 503, body: "") : ok("{}")
        }
        defer { server.stop() }
        let backend = try HTTPBackend(baseURL: server.baseURL)

        await #expect(throws: HTTPTransientError.self) {
            try await backend.create(
                languages: ["pt", "en", "de"],
                namespace: "t",
                key: "k",
                fallbackValue: "v",
                isUpdate: false
            )
        }
        #expect(Set(server.requests.map(\.path)) == ["/locales/add/pt/t", "/locales/add/en/t", "/locales/add/de/t"])
    }

    @Test func customAddPathSupportsPrefixAndQuery() async throws {
        let server = try TestServer { _, _ in ok("{}") }
        defer { server.stop() }
        let backend = try HTTPBackend(
            baseURL: server.baseURL + "/app",
            addPath: "/save/{{ns}}?lng={{lng}}&v=1"
        )

        try await backend.create(languages: ["pt"], namespace: "common", key: "k", fallbackValue: "v", isUpdate: true)

        let post = try #require(server.requests.first)
        #expect(post.path == "/app/save/common")
        #expect(post.target.contains("lng=pt") && post.target.contains("v=1"))
    }

    @Test func aNilAddPathSendsNothing() async throws {
        let server = try TestServer { _, _ in ok("{}") }
        defer { server.stop() }
        let backend = try HTTPBackend(baseURL: server.baseURL, addPath: nil)

        try await backend.create(languages: ["pt"], namespace: "t", key: "k", fallbackValue: "v", isUpdate: false)

        #expect(server.requests.isEmpty)
    }

    /// What `create` throws for a server that always answers `status`, as text, or "no error".
    private func outcome(for status: Int) async throws -> (thrown: String, requests: Int) {
        let server = try TestServer { _, _ in .init(status: status, body: "") }
        defer { server.stop() }
        let backend = try HTTPBackend(baseURL: server.baseURL)
        do {
            try await backend.create(languages: ["pt"], namespace: "t", key: "k", fallbackValue: nil, isUpdate: false)
            return ("no error", server.requests.count)
        } catch let error as HTTPTransientError {
            return ("transient \(error.statusCode.map(String.init) ?? "nil")", server.requests.count)
        } catch HTTPBackendError.unexpectedStatus(let code) {
            return ("unexpected \(code)", server.requests.count)
        } catch {
            return ("other \(error)", server.requests.count)
        }
    }

    @Test(arguments: [
        (408, "transient 408"), (425, "transient 425"), (429, "transient 429"), (500, "transient 500"),
        (503, "transient 503"), (400, "unexpected 400"), (403, "unexpected 403"), (301, "unexpected 301"),
        (200, "no error"), (204, "no error"),
    ])
    func statusesAreMapped(status: Int, expected: String) async throws {
        let result = try await outcome(for: status)
        #expect(result.thrown == expected, "status \(status), \(result.requests) request(s) reached the server")
    }

    @Test func rejectsUnsafeLanguageAndNamespace() async throws {
        let server = try TestServer { _, _ in ok("{}") }
        defer { server.stop() }
        let backend = try HTTPBackend(baseURL: server.baseURL)

        for (languages, namespace) in [(["../x"], "t"), (["pt", "a/b"], "t"), (["pt"], "..")] {
            await #expect(throws: BackendError.self) {
                try await backend.create(
                    languages: languages,
                    namespace: namespace,
                    key: "k",
                    fallbackValue: nil,
                    isUpdate: false
                )
            }
        }
        #expect(server.requests.isEmpty)
    }
}
#endif

@Suite("HTTPBackend configuration")
struct HTTPBackendConfigurationTests {
    @Test func validatesBaseURL() {
        for bad in [
            "", "example.com", "ftp://example.com", "https://", "https://example.com?x=1", "https://example.com#f",
            "//example.com",
        ] {
            #expect(throws: HTTPBackendError.self, "\(bad)") { try HTTPBackend(baseURL: bad) }
        }
        #expect(throws: HTTPBackendError.self) { try HTTPBackend(baseURL: "https://example.com", timeoutSeconds: 0) }
        #expect((try? HTTPBackend(baseURL: "https://example.com:8443/app/")) != nil)
        #expect((try? HTTPBackend(baseURL: "http://localhost:3000")) != nil)
    }

    @Test func addPathDefaultsToI18nextHTTPBackends() throws {
        let backend = try HTTPBackend(baseURL: "https://example.com")
        #expect(backend.addPath == "locales/add/{{lng}}/{{ns}}")
        #expect(backend.expandedAddPath(language: "pt", namespace: "common").path == "locales/add/pt/common")
    }

    @Test func expandsLoadPath() throws {
        let backend = try HTTPBackend(
            baseURL: "https://example.com",
            loadPath: "/l/{{lng}}/{{ns}}.json?lng={{lng}}&x=1&flag"
        )
        let expanded = backend.expandedLoadPath(language: "pt", namespace: "common")
        #expect(expanded.path == "l/pt/common.json")
        #expect(expanded.query.map { "\($0.0)=\($0.1)" } == ["lng=pt", "x=1", "flag="])
    }
}
