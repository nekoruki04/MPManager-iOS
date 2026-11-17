import Foundation
import Darwin
import UIKit

public final class McpServer: @unchecked Sendable {
    public static let shared = McpServer()

    private var server_fd: Int32 = -1
    private var read_source: DispatchSourceRead?
    private let server_queue = DispatchQueue(label: "io.github.abdurazaaqmohammed.mcp.server", attributes: .concurrent)
    private var bg_task_id: UIBackgroundTaskIdentifier = .invalid

    public private(set) var is_running = false
    public private(set) var port: UInt16 = 8787
    public var on_log_message: ((String) -> Void)?

    private let mcp_protocol = McpProtocol()

    private init() {}

    public func start(port: UInt16 = 8787) throws {
        guard !is_running else { return }
        self.port = port

        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Failed to create socket: \(errno)"])
        }

        var opt: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &opt, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = in_addr_t(0)

        let bind_res = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bind_res == 0 else {
            let err = errno
            close(fd)
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(err), userInfo: [NSLocalizedDescriptionKey: "Bind failed on port \(port): errno \(err)"])
        }

        guard listen(fd, 32) == 0 else {
            let err = errno
            close(fd)
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(err), userInfo: [NSLocalizedDescriptionKey: "Listen failed: errno \(err)"])
        }

        self.server_fd = fd
        self.is_running = true

        begin_background_task()

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: server_queue)
        source.setEventHandler { [weak self] in
            self?.accept_connection()
        }
        source.setCancelHandler {
            close(fd)
        }
        self.read_source = source
        source.resume()

        log("[MCP] Server listening on port \(port) (HTTP/JSON-RPC 2.0 & SSE)")
    }

    public func stop() {
        guard is_running else { return }
        is_running = false

        read_source?.cancel()
        read_source = nil
        server_fd = -1

        end_background_task()
        log("[MCP] Server stopped")
    }

    private func accept_connection() {
        var client_addr = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let client_fd = withUnsafeMutablePointer(to: &client_addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                accept(server_fd, $0, &len)
            }
        }

        guard client_fd >= 0 else { return }

        var opt: Int32 = 1
        setsockopt(client_fd, SOL_SOCKET, SO_NOSIGPIPE, &opt, socklen_t(MemoryLayout<Int32>.size))

        server_queue.async { [weak self] in
            self?.handle_client(client_fd: client_fd)
        }
    }

    private func handle_client(client_fd: Int32) {
        defer { close(client_fd) }

        var buffer = [UInt8](repeating: 0, count: 65536)
        var received_data = Data()

        while true {
            let read_bytes = recv(client_fd, &buffer, buffer.count, 0)
            if read_bytes <= 0 { break }
            received_data.append(buffer, count: read_bytes)

            if let range = received_data.range(of: Data("\r\n\r\n".utf8)) {
                let header_data = received_data.subdata(in: 0..<range.lowerBound)
                guard let header_str = String(data: header_data, encoding: .utf8) else { break }

                var content_length = 0
                for line in header_str.components(separatedBy: "\r\n") {
                    if line.lowercased().hasPrefix("content-length:") {
                        let parts = line.split(separator: ":")
                        if parts.count > 1 {
                            content_length = Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
                        }
                    }
                }

                let body_start = range.upperBound
                let current_body_len = received_data.count - body_start
                if current_body_len < content_length {
                    continue
                }

                let body_data = received_data.subdata(in: body_start..<(body_start + content_length))
                process_http_request(client_fd: client_fd, header_str: header_str, body_data: body_data)
                break
            }
        }
    }

    private func process_http_request(client_fd: Int32, header_str: String, body_data: Data) {
        let first_line = header_str.components(separatedBy: "\r\n").first ?? ""
        let parts = first_line.split(separator: " ")
        guard parts.count >= 2 else {
            send_http_response(client_fd: client_fd, status: 400, body: Data("{\"error\":\"Bad Request\"}".utf8))
            return
        }

        let method = String(parts[0]).uppercased()
        let path = String(parts[1])

        log("[MCP] \(method) \(path)")

        if method == "OPTIONS" {
            send_cors_response(client_fd: client_fd)
            return
        }

        if method == "GET" && (path == "/" || path == "/status") {
            let info: [String: Any] = [
                "name": McpProtocol.server_name,
                "version": McpProtocol.server_version,
                "protocol": McpProtocol.protocol_version,
                "status": "ready",
                "endpoints": [
                    "mcp": "/mcp",
                    "sse": "/sse",
                    "tools": "\(McpToolRegistry.shared.list_tools().count) registered tools"
                ]
            ]
            let data = (try? JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted])) ?? Data()
            send_http_response(client_fd: client_fd, status: 200, body: data)
            return
        }

        if method == "POST" && (path == "/mcp" || path.hasPrefix("/message")) {
            let semaphore = DispatchSemaphore(value: 0)
            Task {
                let response_data = await self.mcp_protocol.process_json_rpc(payload: body_data)
                self.send_http_response(client_fd: client_fd, status: 200, body: response_data)
                semaphore.signal()
            }
            semaphore.wait()
            return
        }

        if method == "GET" && (path == "/mcp" || path == "/sse") {
            let session_id = UUID().uuidString
            let endpoint_event = "event: endpoint\ndata: /message?sessionId=\(session_id)\n\n"
            let init_resp = "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-cache\r\nConnection: keep-alive\r\nAccess-Control-Allow-Origin: *\r\n\r\n\(endpoint_event)"
            _ = init_resp.withCString { ptr in
                send(client_fd, ptr, strlen(ptr), 0)
            }
            return
        }

        send_http_response(client_fd: client_fd, status: 404, body: Data("{\"error\":\"Endpoint not found\"}".utf8))
    }

    private func send_cors_response(client_fd: Int32) {
        let resp = "HTTP/1.1 204 No Content\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET, POST, OPTIONS, DELETE\r\nAccess-Control-Allow-Headers: Content-Type, Authorization\r\nConnection: close\r\n\r\n"
        _ = resp.withCString { send(client_fd, $0, strlen($0), 0) }
    }

    private func send_http_response(client_fd: Int32, status: Int, body: Data) {
        let status_text = status == 200 ? "OK" : (status == 400 ? "Bad Request" : (status == 404 ? "Not Found" : "Error"))
        let header = "HTTP/1.1 \(status) \(status_text)\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
        var full_data = Data(header.utf8)
        full_data.append(body)
        full_data.withUnsafeBytes { ptr in
            _ = send(client_fd, ptr.baseAddress!, full_data.count, 0)
        }
    }

    private func begin_background_task() {
        if bg_task_id == .invalid {
            bg_task_id = UIApplication.shared.beginBackgroundTask(withName: "MPManager.McpServer") { [weak self] in
                self?.end_background_task()
            }
        }
    }

    private func end_background_task() {
        if bg_task_id != .invalid {
            UIApplication.shared.endBackgroundTask(bg_task_id)
            bg_task_id = .invalid
        }
    }

    private func log(_ msg: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(msg)"
        DispatchQueue.main.async { [weak self] in
            self?.on_log_message?(line)
        }
    }

    public func get_wifi_address() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first_addr = ifaddr else { return nil }
        var ptr: UnsafeMutablePointer<ifaddrs>? = first_addr
        while ptr != nil {
            let interface = ptr!.pointee
            let addr_family = interface.ifa_addr.pointee.sa_family
            if addr_family == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                    break
                }
            }
            ptr = interface.ifa_next
        }
        freeifaddrs(first_addr)
        return address
    }
}
