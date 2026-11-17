import Foundation
import Darwin

public struct RootlessPaths: Sendable {
    public static var resolved_jailbreak_path: String {
        let bundle_str = Bundle.main.bundlePath
        if let jb_range = bundle_str.range(of: ".jbroot-") ?? bundle_str.range(of: "jbroot-") {
            let prefix = String(bundle_str[..<jb_range.upperBound])
            let rest = String(bundle_str[jb_range.upperBound...])
            let folder_part = rest.components(separatedBy: "/").first ?? ""
            let detected_root = prefix + folder_part
            if FileManager.default.fileExists(atPath: detected_root) {
                return detected_root
            }
        }

        if FileManager.default.fileExists(atPath: "/var/jb") || opendir("/var/jb") != nil {
            return "/var/jb"
        }

        if let app_entries = try? FileManager.default.contentsOfDirectory(atPath: "/private/var/containers/Bundle/Application") {
            for entry in app_entries where entry.contains("jbroot-") {
                let full = "/private/var/containers/Bundle/Application/" + entry
                if FileManager.default.fileExists(atPath: full) {
                    return full
                }
            }
        }

        if let preboot_entries = try? FileManager.default.contentsOfDirectory(atPath: "/private/preboot") {
            for entry in preboot_entries {
                let candidate_dir = "/private/preboot/" + entry
                if let sub_entries = try? FileManager.default.contentsOfDirectory(atPath: candidate_dir) {
                    for sub in sub_entries where sub.contains("jbroot-") {
                        let full = candidate_dir + "/" + sub
                        if FileManager.default.fileExists(atPath: full) {
                            return full
                        }
                    }
                }
            }
        }

        return default_mobile_documents
    }

    public static var default_mobile_documents: String {
        let mobile_doc = "/var/mobile/Media"
        if FileManager.default.fileExists(atPath: mobile_doc) {
            return mobile_doc
        }
        return NSHomeDirectory()
    }

    public static var applications_path: String {
        let jb_apps = resolved_jailbreak_path + "/Applications"
        if FileManager.default.fileExists(atPath: jb_apps) {
            return jb_apps
        }
        return "/Applications"
    }

    public static func resolve_shell() -> String {
        let root = resolved_jailbreak_path
        let candidates = [
            root + "/bin/sh",
            root + "/usr/bin/sh",
            root + "/bin/bash",
            root + "/usr/bin/zsh",
            "/var/jb/bin/sh",
            "/var/jb/usr/bin/sh",
            "/var/jb/bin/bash",
            "/bin/sh",
            "/bin/bash",
            "/usr/bin/sh"
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) } ?? "/bin/sh"
    }

    public static var system_path_env: String {
        let root = resolved_jailbreak_path
        return "\(root)/usr/bin:\(root)/bin:/var/jb/usr/bin:/var/jb/bin:/usr/bin:/bin"
    }

    public static func jb(_ relative_path: String) -> String {
        return resolve_rootless(relative_path)
    }

    public static func resolve_rootless(_ relative_path: String) -> String {
        let cleaned = relative_path.hasPrefix("/") ? String(relative_path.dropFirst()) : relative_path
        let candidate = (resolved_jailbreak_path as NSString).appendingPathComponent(cleaned)
        if FileManager.default.fileExists(atPath: candidate) {
            return candidate
        }
        return "/" + cleaned
    }
}
