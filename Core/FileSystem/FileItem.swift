import Foundation

public struct FileItem: Identifiable, Hashable, Sendable {
    public var id: String { path }
    public let path: String
    public let name: String
    public let file_extension: String
    public let is_directory: Bool
    public let is_symlink: Bool
    public let symlink_target: String?
    public let size: Int64
    public let permissions: mode_t
    public let owner_id: uid_t
    public let group_id: gid_t
    public let owner_name: String
    public let group_name: String
    public let modification_date: Date
    public let creation_date: Date
    public let is_hidden: Bool
    public let is_readable: Bool
    public let is_writable: Bool

    public static func format_bytes(_ size: Int64) -> String {
        let b = Double(size)
        if b < 1024 { return "\(size) B" }
        if b < 1024 * 1024 { return String(format: "%.1f KB", b / 1024.0) }
        if b < 1024 * 1024 * 1024 { return String(format: "%.1f MB", b / (1024.0 * 1024.0)) }
        return String(format: "%.2f GB", b / (1024.0 * 1024.0 * 1024.0))
    }

    public var formatted_size: String {
        if is_directory { return "" }
        return FileItem.format_bytes(size)
    }

    public var octal_permissions: String {
        String(format: "%04o", permissions & 0o7777)
    }

    public var posix_permissions_string: String {
        var str = is_directory ? "d" : (is_symlink ? "l" : "-")
        str += (permissions & S_IRUSR) != 0 ? "r" : "-"
        str += (permissions & S_IWUSR) != 0 ? "w" : "-"
        str += (permissions & S_ISUID) != 0 ? ((permissions & S_IXUSR) != 0 ? "s" : "S") : ((permissions & S_IXUSR) != 0 ? "x" : "-")
        str += (permissions & S_IRGRP) != 0 ? "r" : "-"
        str += (permissions & S_IWGRP) != 0 ? "w" : "-"
        str += (permissions & S_ISGID) != 0 ? ((permissions & S_IXGRP) != 0 ? "s" : "S") : ((permissions & S_IXGRP) != 0 ? "x" : "-")
        str += (permissions & S_IROTH) != 0 ? "r" : "-"
        str += (permissions & S_IWOTH) != 0 ? "w" : "-"
        str += (permissions & S_ISVTX) != 0 ? ((permissions & S_IXOTH) != 0 ? "t" : "T") : ((permissions & S_IXOTH) != 0 ? "x" : "-")
        return str
    }

    public var formatted_date: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        return df.string(from: modification_date)
    }

    public init(
        path: String,
        name: String,
        file_extension: String,
        is_directory: Bool,
        is_symlink: Bool,
        symlink_target: String?,
        size: Int64,
        permissions: mode_t,
        owner_id: uid_t,
        group_id: gid_t,
        owner_name: String,
        group_name: String,
        modification_date: Date,
        creation_date: Date,
        is_hidden: Bool,
        is_readable: Bool,
        is_writable: Bool
    ) {
        self.path = path
        self.name = name
        self.file_extension = file_extension
        self.is_directory = is_directory
        self.is_symlink = is_symlink
        self.symlink_target = symlink_target
        self.size = size
        self.permissions = permissions
        self.owner_id = owner_id
        self.group_id = group_id
        self.owner_name = owner_name
        self.group_name = group_name
        self.modification_date = modification_date
        self.creation_date = creation_date
        self.is_hidden = is_hidden
        self.is_readable = is_readable
        self.is_writable = is_writable
    }
}
