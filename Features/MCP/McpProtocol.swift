import Foundation

public struct McpJsonRpcRequest: Sendable {
    public let jsonrpc: String
    public let id: AnySendableValue?
    public let method: String
    public let params: [String: AnySendableValue]?
}

public enum AnySendableValue: Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnySendableValue])
    case object([String: AnySendableValue])
    case null

    public var raw_value: Any {
        switch self {
        case .string(let v): return v
        case .int(let v): return v
        case .double(let v): return v
        case .bool(let v): return v
        case .array(let v): return v.map { $0.raw_value }
        case .object(let v): return v.mapValues { $0.raw_value }
        case .null: return NSNull()
        }
    }

    public static func from(_ any: Any) -> AnySendableValue {
        if let s = any as? String { return .string(s) }
        if let b = any as? Bool { return .bool(b) }
        if let i = any as? Int { return .int(i) }
        if let d = any as? Double { return .double(d) }
        if let arr = any as? [Any] { return .array(arr.map { AnySendableValue.from($0) }) }
        if let dict = any as? [String: Any] { return .object(dict.mapValues { AnySendableValue.from($0) }) }
        return .null
    }
}

public final class McpProtocol: Sendable {
    public static let server_name = "MP Manager"
    public static let protocol_version = "2024-11-05"
    public static let server_version = "1.0.0"

    public init() {}

    public func process_json_rpc(payload: Data) async -> Data {
        guard let json_object = try? JSONSerialization.jsonObject(with: payload) else {
            return make_error_response(id: nil, code: -32700, message: "Parse error")
        }

        if let array = json_object as? [[String: Any]] {
            var responses: [[String: Any]] = []
            for item in array {
                if let resp = await handle_single_request(item) {
                    responses.append(resp)
                }
            }
            guard let out_data = try? JSONSerialization.data(withJSONObject: responses) else {
                return make_error_response(id: nil, code: -32603, message: "Serialization error")
            }
            return out_data
        } else if let dict = json_object as? [String: Any] {
            if let resp = await handle_single_request(dict) {
                guard let out_data = try? JSONSerialization.data(withJSONObject: resp) else {
                    return make_error_response(id: nil, code: -32603, message: "Serialization error")
                }
                return out_data
            } else {
                return Data()
            }
        } else {
            return make_error_response(id: nil, code: -32600, message: "Invalid Request")
        }
    }

    private func handle_single_request(_ dict: [String: Any]) async -> [String: Any]? {
        let id = dict["id"]
        guard let method = dict["method"] as? String else {
            if id != nil {
                return error_dict(id: id, code: -32600, message: "Missing method")
            }
            return nil
        }

        let params = dict["params"] as? [String: Any] ?? [:]

        switch method {
        case "initialize":
            let requested_proto = params["protocolVersion"] as? String ?? McpProtocol.protocol_version
            let result: [String: Any] = [
                "protocolVersion": requested_proto,
                "capabilities": [
                    "tools": ["listChanged": false],
                    "resources": ["subscribe": false, "listChanged": false]
                ],
                "serverInfo": [
                    "name": McpProtocol.server_name,
                    "version": McpProtocol.server_version
                ],
                "instructions": "MP Manager iOS on-device file, ZIP, APK, and reverse-engineering MCP server. Tools: mp_file_*, mp_zip_*, mp_apk_*, mp_macho_*, mp_exec_command."
            ]
            return success_dict(id: id, result: result)

        case "notifications/initialized":
            return nil

        case "ping":
            return success_dict(id: id, result: [:])

        case "tools/list":
            let tools = McpToolRegistry.shared.list_tools()
            return success_dict(id: id, result: ["tools": tools])

        case "tools/call":
            guard let name = params["name"] as? String else {
                return error_dict(id: id, code: -32602, message: "Missing tool name in tools/call")
            }
            let arguments = params["arguments"] as? [String: Any] ?? [:]
            let res = await McpToolRegistry.shared.execute_tool(name: name, arguments: arguments)
            return success_dict(id: id, result: res)

        case "resources/list":
            let roots = [
                ["uri": "file:///var/mobile", "name": "Mobile User Home", "mimeType": "inode/directory"],
                ["uri": "file:///var/jb", "name": "Jailbreak Root", "mimeType": "inode/directory"],
                ["uri": "file:///Library", "name": "Library Directory", "mimeType": "inode/directory"]
            ]
            return success_dict(id: id, result: ["resources": roots])

        case "prompts/list":
            return success_dict(id: id, result: ["prompts": []])

        default:
            return error_dict(id: id, code: -32601, message: "Method not found: \(method)")
        }
    }

    private func success_dict(id: Any?, result: [String: Any]) -> [String: Any] {
        var dict: [String: Any] = [
            "jsonrpc": "2.0",
            "result": result
        ]
        if let id = id {
            dict["id"] = id
        } else {
            dict["id"] = NSNull()
        }
        return dict
    }

    private func error_dict(id: Any?, code: Int, message: String) -> [String: Any] {
        var dict: [String: Any] = [
            "jsonrpc": "2.0",
            "error": [
                "code": code,
                "message": message
            ]
        ]
        if let id = id {
            dict["id"] = id
        } else {
            dict["id"] = NSNull()
        }
        return dict
    }

    private func make_error_response(id: Any?, code: Int, message: String) -> Data {
        let dict = error_dict(id: id, code: code, message: message)
        return (try? JSONSerialization.data(withJSONObject: dict)) ?? Data()
    }
}
