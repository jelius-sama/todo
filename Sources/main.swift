import NIO
import NIOHTTP1

enum ServerConfig {
    static let host = "0.0.0.0"
    static let port = 6969
    static let backlog = 256
    static let maxMessagesPerRead = 16
}

@main
struct Entry {
    static func main() {
        let group = MultiThreadedEventLoopGroup(
            numberOfThreads: System.coreCount
        )

        defer {
            // SwiftNIO 2 requires blocking shutdown
            try? group.syncShutdownGracefully()
        }

        do {
            let bootstrap = makeBootstrap(group: group)
            let channel = try bindServer(bootstrap: bootstrap)

            print("HTTP server listening on http://\(ServerConfig.host):\(ServerConfig.port)")

            // Block the main thread until shutdown
            try channel.closeFuture.wait()

        } catch {
            print("Fatal server error:", error)
            exit(1)
        }
    }
}

func makeBootstrap(group: EventLoopGroup) -> ServerBootstrap {
    ServerBootstrap(group: group)
        // Server socket options
        .serverChannelOption(
            ChannelOptions.backlog,
            value: Int32(ServerConfig.backlog)
        )
        .serverChannelOption(
            ChannelOptions.socketOption(.so_reuseaddr),
            value: 1
        )

        // Accepted connection initializer
        .childChannelInitializer { channel in
            channel.pipeline.configureHTTPServerPipeline().flatMap {
                channel.pipeline.addHandler(HTTPHandler())
            }
        }

        // Child socket options
        .childChannelOption(
            ChannelOptions.socketOption(.so_reuseaddr),
            value: 1
        )
        .childChannelOption(
            ChannelOptions.maxMessagesPerRead,
            value: UInt(ServerConfig.maxMessagesPerRead)
        )
}

func bindServer(bootstrap: ServerBootstrap) throws -> Channel {
    try bootstrap
        .bind(host: ServerConfig.host, port: ServerConfig.port)
        .wait()
}

final class HTTPHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    // Capture request data for analytics / routing later
    private var requestBuffer: ByteBuffer?

    func channelRead(
        context: ChannelHandlerContext,
        data: NIOAny
    ) {
        let part = unwrapInboundIn(data)

        switch part {

        case .head(let head):
            _ = head
            requestBuffer = context.channel.allocator.buffer(capacity: 0)

        case .body(var body):
            requestBuffer?.writeBuffer(&body)

        case .end:
            sendResponse(context: context)
            requestBuffer = nil
        }
    }

    private func sendResponse(context: ChannelHandlerContext) {
        let body = "Hello from SwiftNIO 2 HTTP server!\n"

        var headers = HTTPHeaders()
        headers.add(name: "Content-Length", value: "\(body.utf8.count)")
        headers.add(name: "Content-Type", value: "text/plain")
        headers.add(name: "Connection", value: "close")

        let head = HTTPResponseHead(
            version: .http1_1,
            status: .ok,
            headers: headers
        )

        context.write(
            wrapOutboundOut(.head(head)),
            promise: nil
        )

        var buffer = context.channel.allocator.buffer(
            capacity: body.utf8.count
        )
        buffer.writeString(body)

        context.write(
            wrapOutboundOut(.body(.byteBuffer(buffer))),
            promise: nil
        )

        context.writeAndFlush(
            wrapOutboundOut(.end(nil)),
            promise: nil
        )
    }

    func errorCaught(
        context: ChannelHandlerContext,
        error: Error
    ) {
        print("Connection error:", error)
        context.close(promise: nil)
    }
}
