import Foundation
import Darwin

public final class FileSystemProvider: Sendable {
    public static let shared = FileSystemProvider()

    public init() {}

    public func contents_of_directory(at path: String, show_hidden: Bool = true) async throws -> [FileItem] {
        return try await Task.detached(priority: .userInitiated) {
            var items: [FileItem] = []
            guard let dir = opendir((path as NSString).fileSystemRepresentation) else {
                let err = errno
                throw NSError(
                    domain: NSPOSIXErrorDomain,
                    code: Int(err),
                    userInfo: [NSLocalizedDescriptionKey: "Failed to open directory \(path): \(String(cString: strerror(err)))"]
                )
            }
            defer { closedir(dir) }

            while let entry = readdir(dir) {
                let name = withUnsafeBytes(of: entry.pointee.d_name) { raw_ptr -> String in
                    guard let base_address = raw_ptr.baseAddress else { return "" }
                    return String(cString: base_address.assumingMemoryBound(to: CChar.self))
                }

                if name == "." || name == ".." { continue }
                if !show_hidden && name.hasPrefix(".") { continue }

                let full_path = (path as NSString).appendingPathComponent(name)
                if let item = self.stat_item(at: full_path, name: name) {
                    items.append(item)
                }
            }

            return items.sorted { lhs, rhs in
                if lhs.is_directory != rhs.is_directory {
                    return lhs.is_directory
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }.value
    }

    public func stat_item(at full_path: String, name: String? = nil) -> FileItem? {
        var stat_info = stat()
        let c_path = (full_path as NSString).fileSystemRepresentation
        guard lstat(c_path, &stat_info) == 0 else {
            return nil
        }

        let item_name = name ?? (full_path as NSString).lastPathComponent
        let mode = stat_info.st_mode
        let is_dir = (mode & S_IFMT) == S_IFDIR
        let is_sym = (mode & S_IFMT) == S_IFLNK

        var symlink_target: String? = nil
        if is_sym {
            var buffer = [CChar](repeating: 0, count: 1024)
            let len = readlink(c_path, &buffer, 1023)
            if len > 0 {
                buffer[len] = 0
                symlink_target = String(cString: buffer)
            }
        }

        let size: Int64 = is_dir ? 0 : Int64(stat_info.st_size)
        let owner_id = stat_info.st_uid
        let group_id = stat_info.st_gid
        let owner_name = getpwuid(owner_id).map { String(cString: $0.pointee.pw_name) } ?? "\(owner_id)"
        let group_name = getgrgid(group_id).map { String(cString: $0.pointee.gr_name) } ?? "\(group_id)"

        let mod_date = Date(timeIntervalSince1970: TimeInterval(stat_info.st_mtimespec.tv_sec))
        let birth_date = Date(timeIntervalSince1970: TimeInterval(stat_info.st_birthtimespec.tv_sec))

        let is_readable = access(c_path, R_OK) == 0
        let is_writable = access(c_path, W_OK) == 0

        return FileItem(
            path: full_path,
            name: item_name,
            file_extension: (item_name as NSString).pathExtension.lowercased(),
            is_directory: is_dir,
            is_symlink: is_sym,
            symlink_target: symlink_target,
            size: size,
            permissions: mode,
            owner_id: owner_id,
            group_id: group_id,
            owner_name: owner_name,
            group_name: group_name,
            modification_date: mod_date,
            creation_date: birth_date,
            is_hidden: item_name.hasPrefix("."),
            is_readable: is_readable,
            is_writable: is_writable
        )
    }

    public func create_directory(at path: String) throws {
        try PrivilegeManager.create_directory(at: path)
    }

    public func create_file(at path: String, contents: Data? = nil) throws {
        let parent = (path as NSString).deletingLastPathComponent
        try create_directory(at: parent)
        if !FileManager.default.createFile(atPath: path, contents: contents ?? Data(), attributes: nil) {
            if let _ = PrivilegeManager.helper_path {
                try PrivilegeManager.run_helper(action: "touch", arguments: [path])
                if let data = contents, !data.isEmpty {
                    try data.write(to: URL(fileURLWithPath: path))
                }
                return
            }
            throw NSError(domain: "FileSystemProvider", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create file at \(path)"])
        }
    }

    public func set_permissions(_ mode: mode_t, at path: String) throws {
        try PrivilegeManager.set_permissions(mode, at: path)
    }

    public func storage_space(at path: String) -> (total: Int64, free: Int64) {
        var stat_fs = statfs()
        let c_path = (path as NSString).fileSystemRepresentation
        guard statfs(c_path, &stat_fs) == 0 else {
            return (0, 0)
        }
        let block_size = Int64(stat_fs.f_bsize)
        let total = Int64(stat_fs.f_blocks) * block_size
        let free = Int64(stat_fs.f_bavail) * block_size
        return (total, free)
    }
}
