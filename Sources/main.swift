import Foundation
import Socket

private enum ServerConfig {
    static let port: UInt16 = 6969
    static let backlog: Int32 = 10
    static let readBufferSize = 1024
}

@main
struct Entry {
    static func main() async throws {
        let server = try await makeServer()
        print("HTTP server listening on http://localhost:\(ServerConfig.port)")

        await acceptLoop(server: server)
    }
}

private func makeServer() async throws -> Socket {
    let address = IPv4SocketAddress(address: .any, port: ServerConfig.port)
    let server = try await Socket(IPv4Protocol.tcp, bind: address)
    try await server.listen(backlog: Int(ServerConfig.backlog))
    return server
}

private func acceptLoop(server: Socket) async {
    while true {
        do {
            let client = try await server.accept()

            Task {
                await handleClient(client)
            }
        } catch {
            // We cannot reliably pattern-match EAGAIN with this library.
            // accept() is non-blocking, so transient failures are expected.

            let message = String(describing: error)

            // Log only if it *doesn't* look like EAGAIN
            if !message.contains("temporarily unavailable") {
                print("Accept error: \(error)")
            }

            // Yield to avoid busy-looping
            try? await Task.sleep(nanoseconds: 1_000_000)  // 1ms
        }
    }
}

private func handleClient(_ client: Socket) async {
    let requestData = await readRequest(from: client)
    _ = requestData  // retained for future analytics / routing

    let responseData = makeHTTPResponse()

    await writeResponse(responseData, to: client)
    await client.close()
}

private func readRequest(from client: Socket) async -> Data {
    var buffer = Data()

    while true {
        do {
            let chunk = try await client.read(ServerConfig.readBufferSize)

            // Client closed connection
            if chunk.isEmpty {
                break
            }

            buffer.append(chunk)

            // Stop once HTTP headers are complete
            if let text = String(data: buffer, encoding: .utf8),
                text.contains("\r\n\r\n")
            {
                break
            }
        } catch {
            print("Read error: \(error)")
        }
    }

    return buffer
}

private func writeResponse(_ data: Data, to client: Socket) async {
    var written = 0

    while written < data.count {
        do {
            let bytesWritten = try await client.write(data[written...])
            written += bytesWritten
        } catch {
            print("Write error: \(error)")
        }
    }
}

private func makeHTTPResponse() -> Data {
    let body = "Hello, World!\n"

    let response = """
        HTTP/1.1 200 OK\r
        Content-Length: \(body.utf8.count)\r
        Content-Type: text/plain\r
        Connection: close\r
        \r
        \(body)
        """

    return response.data(using: .utf8)!
}
