import Foundation
import Darwin

public enum ArchiveFormat: String, CaseIterable, Sendable {
    case zip = "ZIP (.zip)"
    case tarGz = "TAR.GZ (.tar.gz)"
    case tarBz2 = "TAR.BZ2 (.tar.bz2)"
    case tarXz = "TAR.XZ (.tar.xz)"
    case sevenZip = "7-Zip (.7z)"

    public var file_extension: String {
        switch self {
        case .zip: return "zip"
        case .tarGz: return "tar.gz"
        case .tarBz2: return "tar.bz2"
        case .tarXz: return "tar.xz"
        case .sevenZip: return "7z"
        }
    }
}

public struct ArchiveEntry: Identifiable, Sendable {
    public var id: String { path }
    public let path: String
    public let is_directory: Bool
    public let size: Int64
    public let formatted_size: String
}

public final class ArchiveManager: Sendable {
    public static let shared = ArchiveManager()

    public static func resolve_binary(_ name: String) -> String? {
        let candidates = [
            "/var/jb/usr/bin/\(name)",
            "/var/jb/bin/\(name)",
            "/usr/bin/\(name)",
            "/bin/\(name)"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public static func is_safe_entry_path(_ entry_path: String, destination_directory: String) -> Bool {
        let dest_url = URL(fileURLWithPath: destination_directory).standardizedFileURL
        let combined_url = dest_url.appendingPathComponent(entry_path).standardizedFileURL
        return combined_url.path.hasPrefix(dest_url.path)
    }

    public static func list_entries(at archive_path: String) throws -> [ArchiveEntry] {
        let lower = archive_path.lowercased()
        if lower.hasSuffix(".zip") || lower.hasSuffix(".apk") {
            if let native_entries = NativeZipEngine.list_zip_entries(archive_path: archive_path) {
                return native_entries.map {
                    ArchiveEntry(
                        path: $0.name,
                        is_directory: $0.is_directory,
                        size: $0.uncompressed_size,
                        formatted_size: $0.is_directory ? "<DIR>" : ByteCountFormatter.string(fromByteCount: $0.uncompressed_size, countStyle: .file)
                    )
                }
            }
        }

        guard let tar_bin = resolve_binary("tar") else {
            throw NSError(domain: "ArchiveManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "tar binary not found"])
        }

        let res = try run_command(executable: tar_bin, arguments: ["-tf", archive_path])
        if res.status != 0 {
            if lower.hasSuffix(".zip"), let unzip_bin = resolve_binary("unzip") {
                let u_res = try run_command(executable: unzip_bin, arguments: ["-l", archive_path])
                if u_res.status == 0 {
                    return parse_unzip_listing(u_res.output)
                }
            }
            throw NSError(domain: "ArchiveManager", code: Int(res.status), userInfo: [NSLocalizedDescriptionKey: "Failed to list archive contents"])
        }

        var entries: [ArchiveEntry] = []
        let lines = res.output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            let is_dir = trimmed.hasSuffix("/")
            entries.append(ArchiveEntry(
                path: trimmed,
                is_directory: is_dir,
                size: 0,
                formatted_size: is_dir ? "<DIR>" : ""
            ))
        }
        return entries
    }

    public static func extract_archive(at source_path: String, to destination_directory: String) throws {
        let dest_url = URL(fileURLWithPath: destination_directory).standardizedFileURL
        try FileManager.default.createDirectory(at: dest_url, withIntermediateDirectories: true)
        _ = chmod((dest_url.path as NSString).fileSystemRepresentation, 0o777)

        let lower = source_path.lowercased()

        if lower.hasSuffix(".7z") {
            guard let seven_zip = resolve_binary("7z") ?? resolve_binary("7za") else {
                throw NSError(domain: "ArchiveManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "7z tool not found. Install p7zip from Sileo."])
            }
            let res = try run_command(executable: seven_zip, arguments: ["x", source_path, "-o\(dest_url.path)", "-y"])
            if res.status != 0 {
                throw NSError(domain: "ArchiveManager", code: Int(res.status), userInfo: [NSLocalizedDescriptionKey: "7z extraction failed"])
            }
            return
        }

        if lower.hasSuffix(".rar") {
            guard let unrar = resolve_binary("unrar") else {
                throw NSError(domain: "ArchiveManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "unrar not found"])
            }
            let res = try run_command(executable: unrar, arguments: ["x", "-y", source_path, dest_url.path])
            if res.status != 0 {
                throw NSError(domain: "ArchiveManager", code: Int(res.status), userInfo: [NSLocalizedDescriptionKey: "RAR extraction failed"])
            }
            return
        }

        guard let tar_bin = resolve_binary("tar") else {
            throw NSError(domain: "ArchiveManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "tar binary not found"])
        }

        var flags = "-x"
        if lower.hasSuffix(".tar.gz") || lower.hasSuffix(".tgz") || lower.hasSuffix(".gz") {
            flags += "z"
        } else if lower.hasSuffix(".tar.bz2") || lower.hasSuffix(".tbz2") || lower.hasSuffix(".bz2") {
            flags += "j"
        } else if lower.hasSuffix(".tar.xz") || lower.hasSuffix(".txz") || lower.hasSuffix(".xz") {
            flags += "J"
        }
        flags += "f"

        if lower.hasSuffix(".zip") || lower.hasSuffix(".apk") {
            do {
                try NativeZipEngine.extract_zip(archive_path: source_path, destination_directory: dest_url.path)
                return
            } catch {
                if let unzip_bin = resolve_binary("unzip") {
                    let res = try? run_command(executable: unzip_bin, arguments: ["-q", "-o", source_path, "-d", dest_url.path])
                    if let res = res, res.status == 0 { return }
                }
            }
        }

        let args = [flags, source_path, "--no-same-owner", "-C", dest_url.path]
        let res = try? run_command(executable: tar_bin, arguments: args)
        if let res = res, res.status == 0 {
            return
        }

        if (try? PrivilegeManager.extract_archive(source: source_path, destination: dest_url.path)) != nil {
            return
        }

        let exit_code = res?.status ?? 1
        throw NSError(domain: "ArchiveManager", code: Int(exit_code), userInfo: [NSLocalizedDescriptionKey: "Extraction exited with status \(exit_code)"])
    }

    public static func create_archive(sources: [String], destination_path: String, format: ArchiveFormat) throws {
        let dest_url = URL(fileURLWithPath: destination_path).standardizedFileURL
        let parent_dir = dest_url.deletingLastPathComponent().path
        try FileManager.default.createDirectory(atPath: parent_dir, withIntermediateDirectories: true, attributes: nil)

        switch format {
        case .zip:
            try NativeZipEngine.create_zip(sources: sources, destination_path: destination_path)
            return

        case .tarGz:
            guard let tar_bin = resolve_binary("tar") else {
                throw NSError(domain: "ArchiveManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "tar binary not found"])
            }
            var args = ["-czf", dest_url.path]
            let first_src_parent = (sources[0] as NSString).deletingLastPathComponent
            args.append("-C")
            args.append(first_src_parent)
            for src in sources {
                args.append((src as NSString).lastPathComponent)
            }
            let res = try run_command(executable: tar_bin, arguments: args)
            if res.status != 0 {
                throw NSError(domain: "ArchiveManager", code: Int(res.status), userInfo: [NSLocalizedDescriptionKey: "tar.gz creation failed"])
            }

        case .tarBz2:
            guard let tar_bin = resolve_binary("tar") else {
                throw NSError(domain: "ArchiveManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "tar binary not found"])
            }
            var args = ["-cjf", dest_url.path]
            let first_src_parent = (sources[0] as NSString).deletingLastPathComponent
            args.append("-C")
            args.append(first_src_parent)
            for src in sources {
                args.append((src as NSString).lastPathComponent)
            }
            let res = try run_command(executable: tar_bin, arguments: args)
            if res.status != 0 {
                throw NSError(domain: "ArchiveManager", code: Int(res.status), userInfo: [NSLocalizedDescriptionKey: "tar.bz2 creation failed"])
            }

        case .tarXz:
            guard let tar_bin = resolve_binary("tar") else {
                throw NSError(domain: "ArchiveManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "tar binary not found"])
            }
            var args = ["-cJf", dest_url.path]
            let first_src_parent = (sources[0] as NSString).deletingLastPathComponent
            args.append("-C")
            args.append(first_src_parent)
            for src in sources {
                args.append((src as NSString).lastPathComponent)
            }
            let res = try run_command(executable: tar_bin, arguments: args)
            if res.status != 0 {
                throw NSError(domain: "ArchiveManager", code: Int(res.status), userInfo: [NSLocalizedDescriptionKey: "tar.xz creation failed"])
            }

        case .sevenZip:
            guard let seven_zip = resolve_binary("7z") ?? resolve_binary("7za") else {
                throw NSError(domain: "ArchiveManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "7z binary not found"])
            }
            var args = ["a", "-y", dest_url.path]
            for src in sources {
                args.append(src)
            }
            let res = try run_command(executable: seven_zip, arguments: args)
            if res.status != 0 {
                throw NSError(domain: "ArchiveManager", code: Int(res.status), userInfo: [NSLocalizedDescriptionKey: "7z creation failed"])
            }
        }
    }

    private static func parse_unzip_listing(_ text: String) -> [ArchiveEntry] {
        var entries: [ArchiveEntry] = []
        let lines = text.components(separatedBy: "\n")
        var started = false
        for line in lines {
            if line.contains("-----") {
                if !started {
                    started = true
                    continue
                } else {
                    break
                }
            }
            if !started { continue }
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            if parts.count >= 4 {
                let size = Int64(parts[0]) ?? 0
                let path = parts[3...].joined(separator: " ")
                let is_dir = path.hasSuffix("/")
                entries.append(ArchiveEntry(
                    path: path,
                    is_directory: is_dir,
                    size: size,
                    formatted_size: is_dir ? "<DIR>" : "\(size) B"
                ))
            }
        }
        return entries
    }

    private static func run_command(executable: String, arguments: [String]) throws -> (status: Int32, output: String) {
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
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(spawn_err), userInfo: [NSLocalizedDescriptionKey: "posix_spawn failed for \(executable)"])
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
