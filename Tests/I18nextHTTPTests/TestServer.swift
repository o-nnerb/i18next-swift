// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

import NIOConcurrencyHelpers
import NIOCore
import NIOHTTP1
import NIOPosix

/// Minimal HTTP/1.1 server on a loopback socket: one request per connection, scripted responses.
///
/// Built on SwiftNIO (already in the package graph through RequestDL) so that the same server runs on every platform
/// the tests do. Each server owns its event loop group and its listener: the listener binds `127.0.0.1:0`, so the OS
/// gives every server its own ephemeral port, without `SO_REUSEADDR`, and `stop()` returns only once the listener is
/// closed and the group has shut down. Every response carries `Connection: close` and the connection is closed
/// right after it.
final class TestServer: Sendable {
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

    /// The request log and the scripted answers, shared with the connection handlers on the event loop thread.
    fileprivate final class Recorder: Sendable {
        private let recorded = NIOLockedValueBox<[Request]>([])
        private let handler: @Sendable (Request, Int) -> Response  // request, 1-based count of requests to that path

        init(handler: @escaping @Sendable (Request, Int) -> Response) { self.handler = handler }

        var requests: [Request] { recorded.withLockedValue { $0 } }

        func respond(to request: Request) -> Response {
            let seen = recorded.withLockedValue { requests -> Int in
                requests.append(request)
                return requests.filter { $0.path == request.path }.count
            }
            return handler(request, seen)
        }
    }

    private let recorder: Recorder
    private let group: MultiThreadedEventLoopGroup
    private let listener: any Channel
    let port: Int

    init(handler: @escaping @Sendable (Request, Int) -> Response) throws {
        let recorder = Recorder(handler: handler)
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        do {
            let bootstrap = ServerBootstrap(group: group)
                .serverChannelOption(.backlog, value: 64)
                .childChannelInitializer { channel in
                    channel.eventLoop.makeCompletedFuture {
                        try channel.pipeline.syncOperations.configureHTTPServerPipeline()
                        try channel.pipeline.syncOperations.addHandler(Connection(recorder: recorder))
                    }
                }
            let listener = try bootstrap.bind(host: "127.0.0.1", port: 0).wait()
            guard let port = listener.localAddress?.port else { throw ChannelError.unknownLocalAddress }
            self.listener = listener
            self.port = port
        } catch {
            try? group.syncShutdownGracefully()
            throw error
        }
        self.recorder = recorder
        self.group = group
    }

    var baseURL: String { "http://127.0.0.1:\(port)" }

    var requests: [Request] { recorder.requests }
    func count(of path: String) -> Int { requests.filter { $0.path == path }.count }

    /// What to attach to an assertion: which server it was and what it saw.
    var summary: String {
        let seen = requests.map { "\($0.method) \($0.target)" }
        return "server on port \(port) received \(seen.count) request(s)" + (seen.isEmpty ? "" : ": \(seen)")
    }

    /// Returns once nothing listens on the port any more.
    func stop() {
        try? listener.close().wait()
        try? group.syncShutdownGracefully()
    }

    private final class Connection: ChannelInboundHandler {
        typealias InboundIn = HTTPServerRequestPart
        typealias OutboundOut = HTTPServerResponsePart

        private let recorder: Recorder
        private var head: HTTPRequestHead?
        private var body = ByteBuffer()

        init(recorder: Recorder) { self.recorder = recorder }

        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            switch unwrapInboundIn(data) {
            case .head(let head):
                self.head = head
                body.clear()
            case .body(var chunk):
                body.writeBuffer(&chunk)
            case .end:
                guard let head else { return context.close(promise: nil) }
                var headers: [String: String] = [:]
                for header in head.headers { headers[header.name.lowercased()] = header.value }
                let request = Request(
                    method: head.method.rawValue,
                    target: head.uri,
                    headers: headers,
                    body: String(buffer: body)
                )
                respond(recorder.respond(to: request), context: context)
            }
        }

        func errorCaught(context: ChannelHandlerContext, error: any Error) {
            context.close(promise: nil)
        }

        private func respond(_ response: Response, context: ChannelHandlerContext) {
            let payload = ByteBuffer(string: response.body)
            var headers = HTTPHeaders()
            headers.add(name: "Content-Type", value: "application/json")
            headers.add(name: "Content-Length", value: "\(payload.readableBytes)")
            headers.add(name: "Connection", value: "close")

            let status = HTTPResponseStatus(statusCode: response.status)
            context.write(
                wrapOutboundOut(.head(HTTPResponseHead(version: .http1_1, status: status, headers: headers))),
                promise: nil
            )
            if payload.readableBytes > 0 {
                context.write(wrapOutboundOut(.body(.byteBuffer(payload))), promise: nil)
            }
            let channel = context.channel
            context.writeAndFlush(wrapOutboundOut(.end(nil))).whenComplete { _ in channel.close(promise: nil) }
        }
    }
}
