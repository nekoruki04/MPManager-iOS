import Foundation
import Darwin

public final class PrivilegeManager: Sendable {
    public static let shared = PrivilegeManager()

    public static var helper_path: String? {
        let candidates = [
            Bundle.main.bundlePath + "/mpRootHelper",
            "/var/jb/Applications/MPManager.app/mpRootHelper",
            "/Applications/MPManager.app/mpRootHelper"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public static func run_helper(action: String, arguments: [String]) throws {
        guard let helper = helper_path else {
            throw NSError(
                domain: "PrivilegeManager",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "mpRootHelper not found in application bundle."]
            )
        }

        let full_args = [helper, action] + arguments
        var c_args = full_args.map { strdup($0) }
        c_args.append(nil)
        defer {
            for ptr in c_args where ptr != nil {
                free(ptr)
            }
        }

        var pid: pid_t = 0
        let spawn_err = posix_spawnp(&pid, helper, nil, nil, &c_args, environ)
        if spawn_err != 0 {
            throw NSError(
                domain: NSPOSIXErrorDomain,
                code: Int(spawn_err),
                userInfo: [NSLocalizedDescriptionKey: "posix_spawn failed for \(helper): \(String(cString: strerror(spawn_err)))"]
            )
        }

        var status: Int32 = 0
        waitpid(pid, &status, 0)
        let exit_code = (status >> 8) & 0xff
        if exit_code != 0 {
            throw NSError(
                domain: "PrivilegeManager",
                code: Int(exit_code),
                userInfo: [NSLocalizedDescriptionKey: "Root helper action '\(action)' failed with exit code \(exit_code)"]
            )
        }
    }

    public static func delete_item(at path: String) throws {
        let c_path = (path as NSString).fileSystemRepresentation
        _ = chmod(c_path, 0o777)

        if (try? FileManager.default.removeItem(atPath: path)) != nil {
            if !FileManager.default.fileExists(atPath: path) {
                return
            }
        }

        var stat_info = stat()
        if lstat(c_path, &stat_info) == 0 {
            if (stat_info.st_mode & S_IFMT) == S_IFDIR {
                if rmdir(c_path) == 0 { return }
            } else {
                if unlink(c_path) == 0 { return }
            }
        }

        if let _ = helper_path {
            try run_helper(action: "delete", arguments: [path])
            if !FileManager.default.fileExists(atPath: path) {
                return
            }
        }

        let rm_candidates = ["/var/jb/usr/bin/rm", "/var/jb/bin/rm", "/bin/rm", "/usr/bin/rm"]
        if let rm_bin = rm_candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            let args = [rm_bin, "-rf", path]
            var c_args = args.map { strdup($0) }
            c_args.append(nil)
            defer {
                for ptr in c_args where ptr != nil { free(ptr) }
            }
            var pid: pid_t = 0
            if posix_spawnp(&pid, rm_bin, nil, nil, &c_args, environ) == 0 {
                var status: Int32 = 0
                waitpid(pid, &status, 0)
                if ((status >> 8) & 0xff) == 0 && !FileManager.default.fileExists(atPath: path) {
                    return
                }
            }
        }

        throw NSError(
            domain: NSPOSIXErrorDomain,
            code: Int(EACCES),
            userInfo: [NSLocalizedDescriptionKey: "Permission denied deleting \(path)."]
        )
    }

    public static func extract_archive(source: String, destination: String) throws {
        let dest_url = URL(fileURLWithPath: destination).standardizedFileURL
        _ = chmod((dest_url.path as NSString).fileSystemRepresentation, 0o777)

        if let _ = helper_path {
            try run_helper(action: "extract", arguments: [source, dest_url.path])
            return
        }

        throw NSError(
            domain: "PrivilegeManager",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Root helper required for privileged extraction."]
        )
    }

    public static func set_permissions(_ mode: mode_t, at path: String) throws {
        let rc = chmod((path as NSString).fileSystemRepresentation, mode)
        if rc == 0 { return }

        if let _ = helper_path {
            let octal = String(mode, radix: 8)
            try run_helper(action: "chmod", arguments: [octal, path])
            return
        }

        let err = errno
        throw NSError(
            domain: NSPOSIXErrorDomain,
            code: Int(err),
            userInfo: [NSLocalizedDescriptionKey: "chmod failed: \(String(cString: strerror(err)))"]
        )
    }

    public static func create_directory(at path: String) throws {
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            return
        } catch {
            if let _ = helper_path {
                try run_helper(action: "mkdir", arguments: [path])
                return
            }
            throw error
        }
    }
}
