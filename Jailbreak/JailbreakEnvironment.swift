import Foundation
import Darwin

public enum JailbreakFlavor: String, CustomStringConvertible, Sendable {
    case dopamine2 = "Dopamine 2"
    case dopamine3 = "Dopamine 3"
    case dopamineRootHide = "Dopamine RootHide"
    case genericRootless = "Rootless Environment"
    case jailed = "Standard (Sandboxed)"

    public var description: String { rawValue }
}

public struct ProcessCredentials: Sendable {
    public let uid: uid_t
    public let euid: uid_t
    public let gid: gid_t
    public let egid: gid_t
    public let is_root: Bool
    public let is_unsandboxed: Bool

    public var summary: String {
        "UID: \(uid), EUID: \(euid), GID: \(gid), EGID: \(egid) [\(is_unsandboxed ? "Unsandboxed" : "Sandboxed")]"
    }
}

public struct JailbreakEnvironment: Sendable {
    public static var current_flavor: JailbreakFlavor {
        let fm = FileManager.default
        if fm.fileExists(atPath: "/var/jb/basebin/libroothider.dylib") {
            return .dopamineRootHide
        }
        if fm.fileExists(atPath: "/var/jb/basebin/hookd") {
            return .dopamine3
        }
        if fm.fileExists(atPath: "/var/jb/basebin/jbctl") {
            return .dopamine2
        }
        if fm.fileExists(atPath: "/var/jb") {
            return .genericRootless
        }
        return .jailed
    }

    public static var is_rootless: Bool {
        FileManager.default.fileExists(atPath: "/var/jb")
    }

    public static var credentials: ProcessCredentials {
        let u = getuid()
        let eu = geteuid()
        let g = getgid()
        let eg = getegid()
        let unsandboxed = is_unsandboxed
        return ProcessCredentials(
            uid: u,
            euid: eu,
            gid: g,
            egid: eg,
            is_root: eu == 0,
            is_unsandboxed: unsandboxed
        )
    }

    public static var is_unsandboxed: Bool {
        let can_read_mobile = access("/var/mobile", R_OK) == 0
        let can_read_jb = access("/var/jb", R_OK) == 0
        return can_read_mobile || can_read_jb
    }

    public static var jbctl_path: String? {
        let paths = ["/var/jb/basebin/jbctl", "/var/jb/usr/bin/jbctl"]
        return paths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
