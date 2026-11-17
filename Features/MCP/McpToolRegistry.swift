import Foundation
import Darwin

public final class McpToolRegistry: @unchecked Sendable {
    public static let shared = McpToolRegistry()

    private let tool_definitions: [[String: Any]]

    private init() {
        self.tool_definitions = [
            [
                "name": "mp_file_list_roots",
                "description": "List root storage directories, jailbreak roots (/var/jb), and mount points with capacity info.",
                "inputSchema": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "mp_file_list",
                "description": "List contents of a directory with detailed POSIX metadata (size, permissions, timestamps, directory flags).",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Absolute path to directory"],
                        "show_hidden": ["type": "boolean", "description": "Include hidden files (default true)"]
                    ],
                    "required": ["path"]
                ]
            ],
            [
                "name": "mp_file_info",
                "description": "Get complete file metadata, POSIX stat attributes, and SHA-256 hash.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Absolute file path"],
                        "compute_hash": ["type": "boolean", "description": "Calculate SHA-256 hash (default false)"]
                    ],
                    "required": ["path"]
                ]
            ],
            [
                "name": "mp_file_read_text",
                "description": "Read text content of a file (UTF-8, ASCII) with optional offset and max line count.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Absolute path to file"],
                        "offset": ["type": "integer", "description": "Byte offset to start reading (default 0)"],
                        "max_bytes": ["type": "integer", "description": "Maximum bytes to read (default 524288)"]
                    ],
                    "required": ["path"]
                ]
            ],
            [
                "name": "mp_file_read_bytes",
                "description": "Read raw bytes of a file encoded in base64 or hex.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Absolute path to file"],
                        "encoding": ["type": "string", "description": "Encoding: base64 or hex (default base64)"],
                        "offset": ["type": "integer", "description": "Byte offset"],
                        "length": ["type": "integer", "description": "Number of bytes to read"]
                    ],
                    "required": ["path"]
                ]
            ],
            [
                "name": "mp_file_write_text",
                "description": "Write or overwrite text content to a destination path.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Absolute destination path"],
                        "content": ["type": "string", "description": "Text content to write"],
                        "create_parents": ["type": "boolean", "description": "Create intermediate directories"]
                    ],
                    "required": ["path", "content"]
                ]
            ],
            [
                "name": "mp_file_write_bytes",
                "description": "Write raw binary bytes (base64 or hex) to a file.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Absolute destination path"],
                        "data": ["type": "string", "description": "Encoded byte string"],
                        "encoding": ["type": "string", "description": "Encoding format: base64 or hex"]
                    ],
                    "required": ["path", "data"]
                ]
            ],
            [
                "name": "mp_file_append_text",
                "description": "Append text content to an existing or new file.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Target file path"],
                        "content": ["type": "string", "description": "Content to append"]
                    ],
                    "required": ["path", "content"]
                ]
            ],
            [
                "name": "mp_file_mkdir",
                "description": "Create a new directory (recursive mkdir -p).",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Directory path to create"]
                    ],
                    "required": ["path"]
                ]
            ],
            [
                "name": "mp_file_touch",
                "description": "Create an empty file or update its last modification timestamp.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "File path"]
                    ],
                    "required": ["path"]
                ]
            ],
            [
                "name": "mp_file_copy",
                "description": "Copy a file or directory tree to a new location.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "source": ["type": "string", "description": "Source path"],
                        "destination": ["type": "string", "description": "Destination path"]
                    ],
                    "required": ["source", "destination"]
                ]
            ],
            [
                "name": "mp_file_move",
                "description": "Move or rename a file or directory tree.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "source": ["type": "string", "description": "Source path"],
                        "destination": ["type": "string", "description": "Destination path"]
                    ],
                    "required": ["source", "destination"]
                ]
            ],
            [
                "name": "mp_file_rename",
                "description": "Rename a file or folder in its containing directory.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Original file path"],
                        "new_name": ["type": "string", "description": "New file name"]
                    ],
                    "required": ["path", "new_name"]
                ]
            ],
            [
                "name": "mp_file_delete",
                "description": "Safely delete a file or directory tree (uses setuid root helper for protected paths).",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Target path to delete"]
                    ],
                    "required": ["path"]
                ]
            ],
            [
                "name": "mp_file_search",
                "description": "Search directory for files matching name patterns or containing specific text.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Root search directory"],
                        "query": ["type": "string", "description": "File name substring or pattern"],
                        "content_query": ["type": "string", "description": "Search for text within files"],
                        "recursive": ["type": "boolean", "description": "Search subdirectories"]
                    ],
                    "required": ["path", "query"]
                ]
            ],
            [
                "name": "mp_zip_list",
                "description": "List all entries inside an archive (ZIP, 7Z, TAR, TAR.GZ, TAR.BZ2, TAR.XZ) without extraction.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Path to archive file"]
                    ],
                    "required": ["path"]
                ]
            ],
            [
                "name": "mp_zip_extract",
                "description": "Extract archive contents to destination folder with Zip Slip path traversal defense.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "source": ["type": "string", "description": "Archive file path"],
                        "destination": ["type": "string", "description": "Target extraction folder"],
                        "entries": ["type": "array", "items": ["type": "string"], "description": "Optional subset of entries to extract"]
                    ],
                    "required": ["source", "destination"]
                ]
            ],
            [
                "name": "mp_zip_create",
                "description": "Create a new ZIP or TAR archive containing specified files or directories.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "destination": ["type": "string", "description": "Target archive file path (.zip, .tar.gz)"],
                        "sources": ["type": "array", "items": ["type": "string"], "description": "List of paths to compress"]
                    ],
                    "required": ["destination", "sources"]
                ]
            ],
            [
                "name": "mp_apk_info",
                "description": "Inspect an Android APK: decodes binary AndroidManifest.xml, counts DEX classes/methods, checks V1/V2/V3 signatures.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Path to .apk file"]
                    ],
                    "required": ["path"]
                ]
            ],
            [
                "name": "mp_macho_info",
                "description": "Inspect native Mach-O binary headers, slices (arm64, arm64e), load commands, segments, and linked dylibs.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Path to Mach-O executable or dylib"]
                    ],
                    "required": ["path"]
                ]
            ],
            [
                "name": "mp_exec_command",
                "description": "Execute a shell command with rootless jailbreak privilege elevation.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "command": ["type": "string", "description": "Shell command to run"]
                    ],
                    "required": ["command"]
                ]
            ],
            [
                "name": "mp_network_list",
                "description": "List all configured remote network connections (FTP, FTPS, SFTP, WebDAV, SMB).",
                "inputSchema": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "mp_ftp_server_status",
                "description": "Check whether the on-device FTP server is active, its port, and connected network IP.",
                "inputSchema": [
                    "type": "object",
                    "properties": [:]
                ]
            ]
        ]
    }

    public func list_tools() -> [[String: Any]] {
        return tool_definitions
    }

    public func execute_tool(name: String, arguments: [String: Any]) async -> [String: Any] {
        do {
            let text_result = try await dispatch_tool(name: name, arguments: arguments)
            return [
                "content": [
                    [
                        "type": "text",
                        "text": text_result
                    ]
                ],
                "isError": false
            ]
        } catch {
            return [
                "content": [
                    [
                        "type": "text",
                        "text": "Tool error: \(error.localizedDescription)"
                    ]
                ],
                "isError": true
            ]
        }
    }

    private func dispatch_tool(name: String, arguments: [String: Any]) async throws -> String {
        switch name {
        case "mp_file_list_roots":
            var roots: [[String: Any]] = []
            let candidates = [
                ("User Home", "/var/mobile"),
                ("Jailbreak Root", RootlessPaths.resolved_jailbreak_path),
                ("System Applications", "/Applications"),
                ("System Library", "/Library"),
                ("Root Filesystem", "/")
            ]
            for (title, path) in candidates {
                let (tot, free) = FileSystemProvider.shared.storage_space(at: path)
                roots.append([
                    "name": title,
                    "path": path,
                    "total_bytes": tot,
                    "free_bytes": free,
                    "is_accessible": FileManager.default.isReadableFile(atPath: path)
                ])
            }
            return serialize_json(roots)

        case "mp_file_list":
            guard let path = arguments["path"] as? String else {
                throw make_err("Missing required argument: path")
            }
            let show_hidden = arguments["show_hidden"] as? Bool ?? true
            let items = try await FileSystemProvider.shared.contents_of_directory(at: path)
            let filtered = show_hidden ? items : items.filter { !$0.name.hasPrefix(".") }
            let res = filtered.map { [
                "name": $0.name,
                "path": $0.path,
                "is_directory": $0.is_directory,
                "is_symlink": $0.is_symlink,
                "size": $0.size,
                "permissions": $0.octal_permissions,
                "posix_permissions": $0.posix_permissions_string,
                "modification_date": $0.modification_date.timeIntervalSince1970
            ] }
            return serialize_json(res)

        case "mp_file_info":
            guard let path = arguments["path"] as? String else {
                throw make_err("Missing required argument: path")
            }
            guard let item = FileSystemProvider.shared.stat_item(at: path) else {
                throw make_err("File not found or unreadable: \(path)")
            }
            var info: [String: Any] = [
                "name": item.name,
                "path": item.path,
                "is_directory": item.is_directory,
                "is_symlink": item.is_symlink,
                "size": item.size,
                "permissions": item.octal_permissions,
                "posix_permissions": item.posix_permissions_string,
                "uid": item.owner_id,
                "gid": item.group_id,
                "owner": item.owner_name,
                "group": item.group_name,
                "modification_date": item.modification_date.timeIntervalSince1970
            ]
            if arguments["compute_hash"] as? Bool == true, !item.is_directory {
                if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                    info["sha256"] = CryptEngine.shared.sha256_hex(data: data)
                }
            }
            return serialize_json(info)

        case "mp_file_read_text":
            guard let path = arguments["path"] as? String else {
                throw make_err("Missing required argument: path")
            }
            let offset = arguments["offset"] as? Int ?? 0
            let max_bytes = arguments["max_bytes"] as? Int ?? 524288

            guard let handle = FileHandle(forReadingAtPath: path) else {
                throw make_err("Cannot open file for reading: \(path)")
            }
            defer { try? handle.close() }
            if offset > 0 {
                try handle.seek(toOffset: UInt64(offset))
            }
            let data = handle.readData(ofLength: max_bytes)
            guard let str = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
                throw make_err("File is binary or not valid UTF-8/ASCII")
            }
            return str

        case "mp_file_read_bytes":
            guard let path = arguments["path"] as? String else {
                throw make_err("Missing required argument: path")
            }
            let encoding = arguments["encoding"] as? String ?? "base64"
            let offset = arguments["offset"] as? Int ?? 0
            let length = arguments["length"] as? Int ?? 65536

            guard let handle = FileHandle(forReadingAtPath: path) else {
                throw make_err("Cannot open file: \(path)")
            }
            defer { try? handle.close() }
            if offset > 0 {
                try handle.seek(toOffset: UInt64(offset))
            }
            let data = handle.readData(ofLength: length)
            if encoding == "hex" {
                return data.map { String(format: "%02x", $0) }.joined()
            } else {
                return data.base64EncodedString()
            }

        case "mp_file_write_text":
            guard let path = arguments["path"] as? String,
                  let content = arguments["content"] as? String else {
                throw make_err("Missing path or content")
            }
            if arguments["create_parents"] as? Bool == true {
                let dir = (path as NSString).deletingLastPathComponent
                try FileSystemProvider.shared.create_directory(at: dir)
            }
            guard let data = content.data(using: .utf8) else {
                throw make_err("Failed to encode text as UTF-8")
            }
            try FileSystemProvider.shared.create_file(at: path, contents: data)
            return "Wrote \(data.count) bytes to \(path)"

        case "mp_file_write_bytes":
            guard let path = arguments["path"] as? String,
                  let str = arguments["data"] as? String else {
                throw make_err("Missing path or data")
            }
            let enc = arguments["encoding"] as? String ?? "base64"
            let data: Data?
            if enc == "hex" {
                data = hex_to_data(str)
            } else {
                data = Data(base64Encoded: str)
            }
            guard let raw_data = data else {
                throw make_err("Failed to decode byte payload")
            }
            try FileSystemProvider.shared.create_file(at: path, contents: raw_data)
            return "Wrote \(raw_data.count) binary bytes to \(path)"

        case "mp_file_append_text":
            guard let path = arguments["path"] as? String,
                  let content = arguments["content"] as? String else {
                throw make_err("Missing path or content")
            }
            guard let data = content.data(using: .utf8) else {
                throw make_err("Encoding error")
            }
            if !FileManager.default.fileExists(atPath: path) {
                try FileSystemProvider.shared.create_file(at: path, contents: data)
            } else {
                guard let handle = FileHandle(forWritingAtPath: path) else {
                    throw make_err("Cannot open for appending: \(path)")
                }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            }
            return "Appended \(data.count) bytes to \(path)"

        case "mp_file_mkdir":
            guard let path = arguments["path"] as? String else {
                throw make_err("Missing path")
            }
            try FileSystemProvider.shared.create_directory(at: path)
            return "Created directory \(path)"

        case "mp_file_touch":
            guard let path = arguments["path"] as? String else {
                throw make_err("Missing path")
            }
            if !FileManager.default.fileExists(atPath: path) {
                try FileSystemProvider.shared.create_file(at: path, contents: Data())
                return "Created empty file \(path)"
            } else {
                let now = Date()
                try FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: path)
                return "Updated timestamp on \(path)"
            }

        case "mp_file_copy":
            guard let src = arguments["source"] as? String,
                  let dst = arguments["destination"] as? String else {
                throw make_err("Missing source or destination")
            }
            _ = try await FileOperationsQueue.shared.copy_items(sources: [src], destination_directory: dst)
            return "Copied \(src) -> \(dst)"

        case "mp_file_move":
            guard let src = arguments["source"] as? String,
                  let dst = arguments["destination"] as? String else {
                throw make_err("Missing source or destination")
            }
            _ = try await FileOperationsQueue.shared.move_items(sources: [src], destination_directory: dst)
            return "Moved \(src) -> \(dst)"

        case "mp_file_rename":
            guard let path = arguments["path"] as? String,
                  let new_name = arguments["new_name"] as? String else {
                throw make_err("Missing path or new_name")
            }
            try FileOperationsQueue.shared.rename_item(at: path, to: new_name)
            return "Renamed \(path) to \(new_name)"

        case "mp_file_delete":
            guard let path = arguments["path"] as? String else {
                throw make_err("Missing path")
            }
            _ = try await FileOperationsQueue.shared.delete(paths: [path])
            return "Deleted \(path)"

        case "mp_file_search":
            guard let root = arguments["path"] as? String,
                  let query = arguments["query"] as? String else {
                throw make_err("Missing path or query")
            }
            let content_query = arguments["content_query"] as? String
            let query_obj = SearchQuery(root_path: root, name_query: query, content_query: content_query)
            let results = await FileSearchEngine.shared.execute_search(query: query_obj)
            let out = results.map { [
                "path": $0.path,
                "name": $0.name,
                "is_directory": $0.is_directory,
                "size": $0.size,
                "permissions": $0.octal_permissions
            ] }
            return serialize_json(out)

        case "mp_zip_list":
            guard let path = arguments["path"] as? String else {
                throw make_err("Missing archive path")
            }
            let entries = try ArchiveManager.list_entries(at: path)
            let out = entries.map { [
                "path": $0.path,
                "is_directory": $0.is_directory,
                "size": $0.size,
                "formatted_size": $0.formatted_size
            ] }
            return serialize_json(out)

        case "mp_zip_extract":
            guard let src = arguments["source"] as? String,
                  let dst = arguments["destination"] as? String else {
                throw make_err("Missing source or destination")
            }
            try ArchiveManager.extract_archive(at: src, to: dst)
            return "Extracted \(src) to \(dst)"

        case "mp_zip_create":
            guard let dst = arguments["destination"] as? String,
                  let srcs = arguments["sources"] as? [String], !srcs.isEmpty else {
                throw make_err("Missing destination or sources")
            }
            try ArchiveManager.create_archive(sources: srcs, destination_path: dst, format: .zip)
            return "Created archive \(dst) from \(srcs.count) items"

        case "mp_apk_info":
            guard let path = arguments["path"] as? String else {
                throw make_err("Missing apk path")
            }
            let info = try ApkInspector.shared.inspect_apk(at: path)
            let res: [String: Any] = [
                "package_name": info.package_name,
                "version_name": info.version_name,
                "version_code": info.version_code,
                "min_sdk": info.min_sdk,
                "target_sdk": info.target_sdk,
                "dex_count": info.dex_count,
                "native_architectures": info.native_architectures,
                "has_v1_signature": info.has_v1_signature,
                "has_v2_signature": info.has_v2_signature
            ]
            return serialize_json(res)

        case "mp_macho_info":
            guard let path = arguments["path"] as? String else {
                throw make_err("Missing macho path")
            }
            let info = try MachOInspector.shared.inspect(at: path)
            let res: [String: Any] = [
                "path": path,
                "architecture": info.architecture,
                "file_type": info.file_type,
                "load_commands_count": info.load_commands_count,
                "platform": info.platform,
                "min_os": info.min_os,
                "sdk_version": info.sdk_version,
                "linked_dylibs": info.linked_dylibs,
                "segments": info.segments
            ]
            return serialize_json(res)

        case "mp_exec_command":
            guard let cmd = arguments["command"] as? String else {
                throw make_err("Missing command")
            }
            let out = try PrivilegeManager.shared.execute_root_command(cmd)
            return out

        case "mp_network_list":
            let defaults_key = "mp_network_connections_v1"
            if let data = UserDefaults.standard.data(forKey: defaults_key),
               let list = try? JSONDecoder().decode([NetworkStorageItem].self, from: data) {
                let out = list.map { [
                    "name": $0.name,
                    "proto": $0.proto.rawValue,
                    "host": $0.host,
                    "port": $0.port,
                    "path": $0.path,
                    "username": $0.username
                ] }
                return serialize_json(out)
            }
            return "[]"

        case "mp_ftp_server_status":
            let is_running = FtpServer.shared.is_running
            let port = FtpServer.shared.port
            let ip = FtpServer.shared.get_wifi_address() ?? "127.0.0.1"
            let res: [String: Any] = [
                "is_running": is_running,
                "port": port,
                "ip": ip,
                "url": is_running ? "ftp://\(ip):\(port)/" : "inactive"
            ]
            return serialize_json(res)

        default:
            throw make_err("Unknown tool: \(name)")
        }
    }

    private func serialize_json(_ obj: Any) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }

    private func hex_to_data(_ hex: String) -> Data? {
        var data = Data()
        var temp = ""
        for char in hex {
            temp.append(char)
            if temp.count == 2 {
                guard let num = UInt8(temp, radix: 16) else { return nil }
                data.append(num)
                temp = ""
            }
        }
        return data
    }

    private func make_err(_ msg: String) -> NSError {
        return NSError(domain: "McpToolRegistry", code: 400, userInfo: [NSLocalizedDescriptionKey: msg])
    }
}
