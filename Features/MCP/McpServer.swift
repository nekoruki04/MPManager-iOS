import Foundation
import Network

public final class McpToolRegistry: Sendable {
    public static let shared = McpToolRegistry()

    public init() {}

    public func handle_tool_call(name: String, arguments: [String: Any]) async -> [String: Any] {
        switch name {
        case "mp_file_list":
            let path = arguments["path"] as? String ?? "/"
            do {
                let items = try await FileSystemProvider.shared.contents_of_directory(at: path)
                let list = items.map { [
                    "name": $0.name,
                    "path": $0.path,
                    "is_directory": $0.is_directory,
                    "size": $0.size,
                    "permissions": $0.octal_permissions
                ] }
                return ["success": true, "items": list]
            } catch {
                return ["success": false, "error": error.localizedDescription]
            }

        case "mp_file_read":
            guard let path = arguments["path"] as? String else {
                return ["success": false, "error": "Missing path"]
            }
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
                return ["success": false, "error": "Failed to read file as text"]
            }
            return ["success": true, "content": text]

        case "mp_file_write":
            guard let path = arguments["path"] as? String,
                  let content = arguments["content"] as? String else {
                return ["success": false, "error": "Missing path or content"]
            }
            do {
                try FileSystemProvider.shared.create_file(at: path, contents: content.data(using: .utf8))
                return ["success": true]
            } catch {
                return ["success": false, "error": error.localizedDescription]
            }

        case "mp_file_delete":
            guard let path = arguments["path"] as? String else {
                return ["success": false, "error": "Missing path"]
            }
            do {
                _ = try await FileOperationsQueue.shared.delete(paths: [path])
                return ["success": true]
            } catch {
                return ["success": false, "error": error.localizedDescription]
            }

        case "mp_zip_list":
            guard let path = arguments["path"] as? String else {
                return ["success": false, "error": "Missing archive path"]
            }
            do {
                let entries = try ArchiveManager.list_entries(at: path)
                let list = entries.map { ["path": $0.path, "is_directory": $0.is_directory, "size": $0.size] }
                return ["success": true, "entries": list]
            } catch {
                return ["success": false, "error": error.localizedDescription]
            }

        case "mp_zip_extract":
            guard let src = arguments["source"] as? String,
                  let dst = arguments["destination"] as? String else {
                return ["success": false, "error": "Missing source or destination"]
            }
            do {
                try ArchiveManager.extract_archive(at: src, to: dst)
                return ["success": true]
            } catch {
                return ["success": false, "error": error.localizedDescription]
            }

        case "mp_apk_info":
            guard let path = arguments["path"] as? String else {
                return ["success": false, "error": "Missing apk path"]
            }
            do {
                let info = try ApkInspector.shared.inspect_apk(at: path)
                return [
                    "success": true,
                    "package_name": info.package_name,
                    "version_name": info.version_name,
                    "version_code": info.version_code,
                    "min_sdk": info.min_sdk,
                    "target_sdk": info.target_sdk,
                    "dex_count": info.dex_count,
                    "native_architectures": info.native_architectures,
                    "has_v1": info.has_v1_signature,
                    "has_v2": info.has_v2_signature
                ]
            } catch {
                return ["success": false, "error": error.localizedDescription]
            }

        default:
            return ["success": false, "error": "Unknown tool: \(name)"]
        }
    }
}

public final class McpServer: @unchecked Sendable {
    public static let shared = McpServer()

    private var listener: NWListener?
    public private(set) var is_running = false
    public private(set) var port: UInt16 = 8787

    private init() {}

    public func start(port: UInt16 = 8787) throws {
        guard !is_running else { return }
        self.port = port
        let params = NWParameters.tcp
        listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)

        listener?.stateUpdateHandler = { [weak self] state in
            if state == .ready {
                self?.is_running = true
            } else if case .failed = state {
                self?.is_running = false
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handle_connection(connection)
        }

        listener?.start(queue: .global(qos: .userInitiated))
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        is_running = false
    }

    private func handle_connection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        read_http_request(connection)
    }

    private func read_http_request(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, is_complete, error in
            guard let self = self, let data = content, error == nil else {
                connection.cancel()
                return
            }

            Task {
                let response_data = await self.process_http_payload(data)
                connection.send(content: response_data, completion: .contentProcessed({ _ in
                    connection.cancel()
                }))
            }
        }
    }

    private func process_http_payload(_ data: Data) async -> Data {
        guard let request_str = String(data: data, encoding: .utf8) else {
            return make_http_response(body: "{\"error\":\"Invalid request encoding\"}", status: 400)
        }

        let parts = request_str.components(separatedBy: "\r\n\r\n")
        let headers = parts.first ?? ""
        let body = parts.count > 1 ? parts[1] : ""

        if headers.contains("GET /mcp") || headers.contains("GET /sse") {
            return make_http_response(body: "{\"status\":\"ok\",\"service\":\"MP Manager MCP Server\"}", status: 200)
        }

        if headers.contains("POST /mcp") {
            guard let body_data = body.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: body_data) as? [String: Any],
                  let tool_name = json["tool"] as? String else {
                return make_http_response(body: "{\"error\":\"Invalid MCP tool payload\"}", status: 400)
            }
            let args = json["arguments"] as? [String: Any] ?? [:]
            let result = await McpToolRegistry.shared.handle_tool_call(name: tool_name, arguments: args)
            if let out_data = try? JSONSerialization.data(withJSONObject: result),
               let out_str = String(data: out_data, encoding: .utf8) {
                return make_http_response(body: out_str, status: 200)
            }
        }

        return make_http_response(body: "{\"error\":\"Not found\"}", status: 404)
    }

    private func make_http_response(body: String, status: Int) -> Data {
        let status_text = status == 200 ? "OK" : (status == 400 ? "Bad Request" : "Not Found")
        let resp = "HTTP/1.1 \(status) \(status_text)\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        return resp.data(using: .utf8)!
    }
}
