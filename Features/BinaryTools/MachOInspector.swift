import Foundation
import MachO

public struct MachOInfo: Sendable {
    public let architecture: String
    public let file_type: String
    public let load_commands_count: Int
    public let platform: String
    public let min_os: String
    public let sdk_version: String
    public let linked_dylibs: [String]
    public let segments: [String]
}

public final class MachOInspector: Sendable {
    public static let shared = MachOInspector()

    public init() {}

    public func inspect(at path: String) throws -> MachOInfo {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped) else {
            throw NSError(domain: "MachOInspector", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to read binary file"])
        }

        guard data.count >= 32 else {
            throw NSError(domain: "MachOInspector", code: 2, userInfo: [NSLocalizedDescriptionKey: "File too small to be a Mach-O binary"])
        }

        let magic = data.subdata(in: 0..<4).withUnsafeBytes { $0.load(as: UInt32.self) }
        guard magic == MH_MAGIC_64 || magic == MH_CIGAM_64 || magic == MH_MAGIC || magic == MH_CIGAM else {
            throw NSError(domain: "MachOInspector", code: 3, userInfo: [NSLocalizedDescriptionKey: "Not a valid Mach-O binary (magic 0x\(String(magic, radix: 16)))"])
        }

        let is_64 = (magic == MH_MAGIC_64 || magic == MH_CIGAM_64)
        let header_size = is_64 ? MemoryLayout<mach_header_64>.size : MemoryLayout<mach_header>.size

        let cputype = data.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: cpu_type_t.self) }
        let cpusubtype = data.subdata(in: 8..<12).withUnsafeBytes { $0.load(as: cpu_subtype_t.self) }
        let filetype = data.subdata(in: 12..<16).withUnsafeBytes { $0.load(as: UInt32.self) }
        let ncmds = Int(data.subdata(in: 16..<20).withUnsafeBytes { $0.load(as: UInt32.self) })

        var arch_str = "arm64"
        if cputype == CPU_TYPE_ARM64 {
            arch_str = (UInt32(bitPattern: cpusubtype) & ~CPU_SUBTYPE_MASK) == UInt32(bitPattern: CPU_SUBTYPE_ARM64E) ? "arm64e" : "arm64"
        } else if cputype == CPU_TYPE_X86_64 {
            arch_str = "x86_64"
        }

        var type_str = "Executable"
        switch filetype {
        case UInt32(MH_EXECUTE): type_str = "Executable"
        case UInt32(MH_DYLIB): type_str = "Dynamic Library (dylib)"
        case UInt32(MH_BUNDLE): type_str = "Bundle"
        case UInt32(MH_OBJECT): type_str = "Object File"
        default: type_str = "Type \(filetype)"
        }

        var platform_str = "iOS"
        var minos_str = "Unknown"
        var sdk_str = "Unknown"
        var dylibs: [String] = []
        var segments: [String] = []

        var offset = header_size
        for _ in 0..<min(ncmds, 128) {
            if offset + 8 > data.count { break }
            let cmd = data.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self) }
            let cmdsize = Int(data.subdata(in: offset+4..<offset+8).withUnsafeBytes { $0.load(as: UInt32.self) })
            if cmdsize <= 0 || offset + cmdsize > data.count { break }

            if cmd == LC_BUILD_VERSION && cmdsize >= 24 {
                let plat = data.subdata(in: offset+8..<offset+12).withUnsafeBytes { $0.load(as: UInt32.self) }
                let minos = data.subdata(in: offset+12..<offset+16).withUnsafeBytes { $0.load(as: UInt32.self) }
                let sdk = data.subdata(in: offset+16..<offset+20).withUnsafeBytes { $0.load(as: UInt32.self) }

                platform_str = plat == 2 ? "iOS" : "Platform \(plat)"
                minos_str = "\(minos >> 16).\((minos >> 8) & 0xff).\((minos) & 0xff)"
                sdk_str = "\(sdk >> 16).\((sdk >> 8) & 0xff).\((sdk) & 0xff)"
            }

            if (cmd == LC_LOAD_DYLIB || cmd == LC_LOAD_WEAK_DYLIB) && cmdsize >= 24 {
                let stroff = Int(data.subdata(in: offset+8..<offset+12).withUnsafeBytes { $0.load(as: UInt32.self) })
                if stroff > 0 && offset + stroff < offset + cmdsize {
                    let dylib_data = data.subdata(in: offset+stroff..<offset+cmdsize)
                    let null_idx = dylib_data.firstIndex(of: 0) ?? dylib_data.endIndex
                    if let s = String(data: dylib_data[dylib_data.startIndex..<null_idx], encoding: .utf8) {
                        dylibs.append((s as NSString).lastPathComponent)
                    }
                }
            }

            if cmd == LC_SEGMENT_64 && cmdsize >= 72 {
                let segname_data = data.subdata(in: offset+8..<offset+24)
                let null_idx = segname_data.firstIndex(of: 0) ?? segname_data.endIndex
                if let s = String(data: segname_data[segname_data.startIndex..<null_idx], encoding: .utf8) {
                    segments.append(s)
                }
            }

            offset += cmdsize
        }

        return MachOInfo(
            architecture: arch_str,
            file_type: type_str,
            load_commands_count: ncmds,
            platform: platform_str,
            min_os: minos_str,
            sdk_version: sdk_str,
            linked_dylibs: dylibs,
            segments: segments
        )
    }
}
