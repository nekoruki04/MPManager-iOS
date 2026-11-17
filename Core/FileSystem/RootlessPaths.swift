import Foundation
import Darwin

public struct RootlessPaths: Sendable {
    public static var resolved_jailbreak_path: String {
        if let dir = opendir("/var/jb") {
            closedir(dir)
            return "/var/jb"
        }
        if let preboot_entries = try? FileManager.default.contentsOfDirectory(atPath: "/private/preboot") {
            for entry in preboot_entries {
                let candidate_dir = "/private/preboot/" + entry
                if let sub_entries = try? FileManager.default.contentsOfDirectory(atPath: candidate_dir) {
                    for sub in sub_entries where sub.hasPrefix("jbroot-") {
                        let full = candidate_dir + "/" + sub
                        if let d = opendir(full) {
                            closedir(d)
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

    public static func resolve_rootless(_ relative_path: String) -> String {
        let cleaned = relative_path.hasPrefix("/") ? String(relative_path.dropFirst()) : relative_path
        let candidate = (resolved_jailbreak_path as NSString).appendingPathComponent(cleaned)
        if FileManager.default.fileExists(atPath: candidate) {
            return candidate
        }
        return "/" + cleaned
    }
}
