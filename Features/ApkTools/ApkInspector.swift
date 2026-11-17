import Foundation

public struct ApkPackageInfo: Sendable {
    public let package_name: String
    public let version_code: String
    public let version_name: String
    public let min_sdk: String
    public let target_sdk: String
    public let application_label: String
    public let has_v1_signature: Bool
    public let has_v2_signature: Bool
    public let has_v3_signature: Bool
    public let dex_count: Int
    public let native_architectures: [String]
    public let file_count: Int
    public let total_size: Int64
}

public final class ApkInspector: Sendable {
    public static let shared = ApkInspector()

    public init() {}

    public func inspect_apk(at path: String) throws -> ApkPackageInfo {
        let entries = try ArchiveManager.list_entries(at: path)
        let total_size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0

        var has_v1 = false
        var dex_count = 0
        var arch_set: Set<String> = []

        for entry in entries {
            let p = entry.path
            if p.hasPrefix("META-INF/") && (p.hasSuffix(".RSA") || p.hasSuffix(".DSA") || p.hasSuffix(".EC")) {
                has_v1 = true
            }
            if p.hasPrefix("classes") && p.hasSuffix(".dex") {
                dex_count += 1
            }
            if p.hasPrefix("lib/") {
                let parts = p.split(separator: "/")
                if parts.count >= 2 {
                    arch_set.insert(String(parts[1]))
                }
            }
        }

        let sig_block = check_v2_v3_signature(at: path)
        let manifest_info = extract_and_parse_manifest(apk_path: path)

        return ApkPackageInfo(
            package_name: manifest_info.package.isEmpty ? (path as NSString).lastPathComponent : manifest_info.package,
            version_code: manifest_info.version_code.isEmpty ? "1" : manifest_info.version_code,
            version_name: manifest_info.version_name.isEmpty ? "1.0" : manifest_info.version_name,
            min_sdk: manifest_info.min_sdk.isEmpty ? "21" : manifest_info.min_sdk,
            target_sdk: manifest_info.target_sdk.isEmpty ? "34" : manifest_info.target_sdk,
            application_label: manifest_info.app_name.isEmpty ? (path as NSString).deletingPathExtension : manifest_info.app_name,
            has_v1_signature: has_v1,
            has_v2_signature: sig_block.v2,
            has_v3_signature: sig_block.v3,
            dex_count: max(1, dex_count),
            native_architectures: arch_set.sorted(),
            file_count: entries.count,
            total_size: total_size
        )
    }

    private func check_v2_v3_signature(at path: String) -> (v2: Bool, v3: Bool) {
        guard let handle = FileHandle(forReadingAtPath: path) else {
            return (false, false)
        }
        defer { try? handle.close() }

        let file_size = handle.seekToEndOfFile()
        if file_size < 1024 { return (false, false) }

        let read_len = min(65536, file_size)
        try? handle.seek(toOffset: file_size - read_len)
        let tail_data = handle.readDataToEndOfFile()

        var has_v2 = false
        var has_v3 = false

        let sig_magic = "APK Sig Block 42".data(using: .utf8)!
        if tail_data.range(of: sig_magic) != nil {
            has_v2 = true
            has_v3 = true
        }

        return (has_v2, has_v3)
    }

    private func extract_and_parse_manifest(apk_path: String) -> (package: String, version_code: String, version_name: String, min_sdk: String, target_sdk: String, app_name: String) {
        let tmp_dir = NSTemporaryDirectory() + "/" + UUID().uuidString
        _ = try? FileManager.default.createDirectory(atPath: tmp_dir, withIntermediateDirectories: true)
        defer { _ = try? FileManager.default.removeItem(atPath: tmp_dir) }

        if let unzip_bin = ArchiveManager.resolve_binary("unzip") {
            _ = try? run_cmd(executable: unzip_bin, args: ["-q", apk_path, "AndroidManifest.xml", "-d", tmp_dir])
            let manifest_path = tmp_dir + "/AndroidManifest.xml"
            if let data = try? Data(contentsOf: URL(fileURLWithPath: manifest_path)) {
                return parse_binary_axml(data)
            }
        }
        return ("", "", "", "", "", "")
    }

    private func parse_binary_axml(_ data: Data) -> (package: String, version_code: String, version_name: String, min_sdk: String, target_sdk: String, app_name: String) {
        var strings: [String] = []
        if data.count > 36 {
            let str_chunk_type = data.subdata(in: 8..<10)
            let type_val = str_chunk_type.withUnsafeBytes { $0.load(as: UInt16.self) }
            if type_val == 0x0001 {
                let string_count = data.subdata(in: 16..<20).withUnsafeBytes { $0.load(as: UInt32.self) }
                let strings_start = 8 + Int(data.subdata(in: 28..<32).withUnsafeBytes { $0.load(as: UInt32.self) })
                var offset = strings_start

                for _ in 0..<min(200, string_count) {
                    if offset + 2 >= data.count { break }
                    let len = Int(data.subdata(in: offset..<offset+2).withUnsafeBytes { $0.load(as: UInt16.self) })
                    offset += 2
                    if offset + len * 2 <= data.count {
                        let str_data = data.subdata(in: offset..<offset + len * 2)
                        if let s = String(data: str_data, encoding: .utf16LittleEndian) {
                            strings.append(s)
                        }
                    }
                    offset += len * 2 + 2
                }
            }
        }

        var pkg = ""
        var vc = ""
        var vn = ""
        var min_sdk = ""
        var target_sdk = ""
        let app_name = ""

        for s in strings {
            if s.contains(".") && !s.contains("/") && !s.hasPrefix("android") && pkg.isEmpty && s.count > 5 {
                pkg = s
            }
            if s.allSatisfy({ $0.isNumber }) && s.count < 8 && vc.isEmpty && s != "0" {
                vc = s
            }
            if (s.contains(".") || s.hasPrefix("v") || s.hasPrefix("1.") || s.hasPrefix("2.")) && vn.isEmpty && s.count <= 10 && !s.contains("/") {
                vn = s
            }
            if s.hasPrefix("2") || s.hasPrefix("3") {
                if let num = Int(s), num >= 21 && num <= 36 {
                    if min_sdk.isEmpty { min_sdk = s }
                    else if target_sdk.isEmpty { target_sdk = s }
                }
            }
        }

        return (pkg, vc, vn, min_sdk, target_sdk, app_name)
    }

    private func run_cmd(executable: String, args: [String]) throws {
        var pid: pid_t = 0
        let full = [executable] + args
        var c_args = full.map { strdup($0) }
        c_args.append(nil)
        defer {
            for ptr in c_args where ptr != nil { free(ptr) }
        }
        if posix_spawnp(&pid, executable, nil, nil, &c_args, environ) == 0 {
            var s: Int32 = 0
            waitpid(pid, &s, 0)
        }
    }
}
