import Foundation
import Darwin

public struct RemoteFileInfo: Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let is_directory: Bool
    public let size: Int64
    public let raw_line: String
}

public final class NetworkStorageClient: Sendable {
    public static let shared = NetworkStorageClient()

    public init() {}

    public func list_directory(item: NetworkStorageItem, path: String, password: String?) async throws -> [RemoteFileInfo] {
        if item.proto == .smb {
            throw NSError(domain: "NetworkStorageClient", code: 501, userInfo: [NSLocalizedDescriptionKey: "SMB2/3 requires external libsmb2 client library."])
        }

        var url_str = "\(item.proto.rawValue.lowercased())://\(item.host):\(item.port)"
        if !path.hasPrefix("/") {
            url_str += "/" + path
        } else {
            url_str += path
        }
        if !url_str.hasSuffix("/") {
            url_str += "/"
        }

        var args = ["-s", "--connect-timeout", "10", "--max-time", "30"]
        if !item.username.isEmpty {
            let cred = item.username + ":" + (password ?? "")
            args += ["-u", cred]
        }
        if item.proto == .ftps {
            args += ["--ssl"]
        }
        args.append(url_str)

        let curl_bin = resolve_curl()
        let result = try run_command(executable: curl_bin, arguments: args)
        if result.status != 0 {
            throw NSError(domain: "NetworkStorageClient", code: Int(result.status), userInfo: [NSLocalizedDescriptionKey: "Remote connection failed with exit status \(result.status)"])
        }

        var list: [RemoteFileInfo] = []
        let lines = result.output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            if parts.count >= 9 {
                let perms = String(parts[0])
                let is_dir = perms.hasPrefix("d")
                let size = Int64(parts[4]) ?? 0
                let name = parts[8...].joined(separator: " ")
                if name == "." || name == ".." { continue }
                list.append(RemoteFileInfo(name: name, is_directory: is_dir, size: size, raw_line: trimmed))
            } else {
                list.append(RemoteFileInfo(name: trimmed, is_directory: false, size: 0, raw_line: trimmed))
            }
        }
        return list
    }

    public func download_file(item: NetworkStorageItem, remote_path: String, local_destination: String, password: String?) async throws {
        if item.proto == .smb {
            throw NSError(domain: "NetworkStorageClient", code: 501, userInfo: [NSLocalizedDescriptionKey: "SMB2/3 not supported"])
        }

        var url_str = "\(item.proto.rawValue.lowercased())://\(item.host):\(item.port)"
        url_str += remote_path.hasPrefix("/") ? remote_path : ("/" + remote_path)

        var args = ["-s", "--connect-timeout", "15", "-o", local_destination]
        if !item.username.isEmpty {
            let cred = item.username + ":" + (password ?? "")
            args += ["-u", cred]
        }
        if item.proto == .ftps {
            args += ["--ssl"]
        }
        args.append(url_str)

        let curl_bin = resolve_curl()
        let result = try run_command(executable: curl_bin, arguments: args)
        if result.status != 0 {
            throw NSError(domain: "NetworkStorageClient", code: Int(result.status), userInfo: [NSLocalizedDescriptionKey: "Download failed with exit status \(result.status)"])
        }
    }

    public func upload_file(item: NetworkStorageItem, local_source: String, remote_path: String, password: String?) async throws {
        if item.proto == .smb {
            throw NSError(domain: "NetworkStorageClient", code: 501, userInfo: [NSLocalizedDescriptionKey: "SMB2/3 not supported"])
        }

        var url_str = "\(item.proto.rawValue.lowercased())://\(item.host):\(item.port)"
        url_str += remote_path.hasPrefix("/") ? remote_path : ("/" + remote_path)

        var args = ["-s", "--connect-timeout", "15", "-T", local_source]
        if !item.username.isEmpty {
            let cred = item.username + ":" + (password ?? "")
            args += ["-u", cred]
        }
        if item.proto == .ftps {
            args += ["--ssl"]
        }
        args.append(url_str)

        let curl_bin = resolve_curl()
        let result = try run_command(executable: curl_bin, arguments: args)
        if result.status != 0 {
            throw NSError(domain: "NetworkStorageClient", code: Int(result.status), userInfo: [NSLocalizedDescriptionKey: "Upload failed with exit status \(result.status)"])
        }
    }

    private func resolve_curl() -> String {
        let candidates = ["/var/jb/usr/bin/curl", "/var/jb/bin/curl", "/usr/bin/curl", "/bin/curl"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? "/usr/bin/curl"
    }

    private func run_command(executable: String, arguments: [String]) throws -> (status: Int32, output: String) {
        var pid: pid_t = 0
        var pipe_fds: [Int32] = [0, 0]
        pipe(&pipe_fds)

        var file_actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&file_actions)
        defer { posix_spawn_file_actions_destroy(&file_actions) }

        posix_spawn_file_actions_adddup2(&file_actions, pipe_fds[1], STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&file_actions, pipe_fds[1], STDERR_FILENO)
        posix_spawn_file_actions_addclose(&file_actions, pipe_fds[0])

        let full_args = [executable] + arguments
        var c_args = full_args.map { strdup($0) }
        c_args.append(nil)
        defer {
            for ptr in c_args where ptr != nil { free(ptr) }
        }

        let spawn_err = posix_spawnp(&pid, executable, &file_actions, nil, &c_args, environ)
        close(pipe_fds[1])

        if spawn_err != 0 {
            close(pipe_fds[0])
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(spawn_err), userInfo: [NSLocalizedDescriptionKey: "Failed to spawn \(executable)"])
        }

        var output = ""
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let read_bytes = read(pipe_fds[0], &buffer, buffer.count)
            if read_bytes <= 0 { break }
            if let str = String(bytes: buffer[0..<read_bytes], encoding: .utf8) {
                output += str
            }
        }
        close(pipe_fds[0])

        var status: Int32 = 0
        waitpid(pid, &status, 0)
        return ((status >> 8) & 0xff, output)
    }
}
