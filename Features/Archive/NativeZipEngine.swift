import Foundation
import zlib

public final class NativeZipEngine: Sendable {
    public struct ZipEntryInfo: Sendable {
        public let name: String
        public let is_directory: Bool
        public let uncompressed_size: Int64
        public let compressed_size: Int64
        public let crc32: UInt32
    }

    private struct InternalEntry {
        let name: String
        let is_dir: Bool
        let crc: UInt32
        let comp_size: UInt32
        let uncomp_size: UInt32
        let local_header_offset: UInt32
        let mod_time: UInt16
        let mod_date: UInt16
    }

    public static func create_zip(sources: [String], destination_path: String) throws {
        let dest_url = URL(fileURLWithPath: destination_path).standardizedFileURL
        let parent_dir = dest_url.deletingLastPathComponent().path
        try FileManager.default.createDirectory(atPath: parent_dir, withIntermediateDirectories: true, attributes: nil)

        if FileManager.default.fileExists(atPath: dest_url.path) {
            try FileManager.default.removeItem(atPath: dest_url.path)
        }
        FileManager.default.createFile(atPath: dest_url.path, contents: nil, attributes: nil)

        guard let handle = FileHandle(forWritingAtPath: dest_url.path) else {
            throw NSError(domain: "NativeZipEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open destination for writing."])
        }

        var entries: [InternalEntry] = []
        var current_offset: UInt32 = 0

        for src in sources {
            var is_dir: ObjCBool = false
            if FileManager.default.fileExists(atPath: src, isDirectory: &is_dir) {
                let base_name = (src as NSString).lastPathComponent
                if is_dir.boolValue {
                    try add_directory_recursive(dir_path: src, base_prefix: base_name, handle: handle, current_offset: &current_offset, entries: &entries)
                } else {
                    try add_single_file(name: base_name, source_path: src, handle: handle, current_offset: &current_offset, entries: &entries)
                }
            }
        }

        let cd_offset = current_offset
        var cd = Data()

        for entry in entries {
            let name_data = Data(entry.name.utf8)
            append_u32(&cd, 0x02014b50)
            append_u16(&cd, 20)
            append_u16(&cd, 20)
            append_u16(&cd, 0)
            append_u16(&cd, entry.comp_size == entry.uncomp_size ? 0 : 8)
            append_u16(&cd, entry.mod_time)
            append_u16(&cd, entry.mod_date)
            append_u32(&cd, entry.crc)
            append_u32(&cd, entry.comp_size)
            append_u32(&cd, entry.uncomp_size)
            append_u16(&cd, UInt16(name_data.count))
            append_u16(&cd, 0)
            append_u16(&cd, 0)
            append_u16(&cd, 0)
            append_u16(&cd, 0)
            append_u32(&cd, entry.is_dir ? 0x10 : 0)
            append_u32(&cd, entry.local_header_offset)
            cd.append(name_data)
        }

        let cd_size = UInt32(cd.count)
        try handle.write(contentsOf: cd)

        var eocd = Data()
        append_u32(&eocd, 0x06054b50)
        append_u16(&eocd, 0)
        append_u16(&eocd, 0)
        append_u16(&eocd, UInt16(entries.count))
        append_u16(&eocd, UInt16(entries.count))
        append_u32(&eocd, cd_size)
        append_u32(&eocd, cd_offset)
        append_u16(&eocd, 0)

        try handle.write(contentsOf: eocd)
        try handle.close()
    }

    private static func add_single_file(name: String, source_path: String, handle: FileHandle, current_offset: inout UInt32, entries: inout [InternalEntry]) throws {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: source_path)) else { return }
        let offset = current_offset
        let (dos_time, dos_date) = dos_date_time()
        let name_data = Data(name.utf8)
        let crc = UInt32(data.withUnsafeBytes { crc32(0, $0.bindMemory(to: Bytef.self).baseAddress, uInt(data.count)) })

        let comp_data: Data
        let comp_method: UInt16
        if let deflated = deflate_data(data), deflated.count < data.count {
            comp_data = deflated
            comp_method = 8
        } else {
            comp_data = data
            comp_method = 0
        }

        var lh = Data()
        append_u32(&lh, 0x04034b50)
        append_u16(&lh, 20)
        append_u16(&lh, 0)
        append_u16(&lh, comp_method)
        append_u16(&lh, dos_time)
        append_u16(&lh, dos_date)
        append_u32(&lh, crc)
        append_u32(&lh, UInt32(comp_data.count))
        append_u32(&lh, UInt32(data.count))
        append_u16(&lh, UInt16(name_data.count))
        append_u16(&lh, 0)
        lh.append(name_data)

        try handle.write(contentsOf: lh)
        try handle.write(contentsOf: comp_data)
        current_offset += UInt32(lh.count + comp_data.count)

        entries.append(InternalEntry(
            name: name,
            is_dir: false,
            crc: crc,
            comp_size: UInt32(comp_data.count),
            uncomp_size: UInt32(data.count),
            local_header_offset: offset,
            mod_time: dos_time,
            mod_date: dos_date
        ))
    }

    private static func add_directory_recursive(dir_path: String, base_prefix: String, handle: FileHandle, current_offset: inout UInt32, entries: inout [InternalEntry]) throws {
        guard let subpaths = FileManager.default.subpaths(atPath: dir_path) else { return }
        for sub in subpaths {
            let full_sub = (dir_path as NSString).appendingPathComponent(sub)
            var is_dir: ObjCBool = false
            if FileManager.default.fileExists(atPath: full_sub, isDirectory: &is_dir) {
                let arc_name = base_prefix.isEmpty ? sub : "\(base_prefix)/\(sub)"
                if !is_dir.boolValue {
                    try add_single_file(name: arc_name, source_path: full_sub, handle: handle, current_offset: &current_offset, entries: &entries)
                }
            }
        }
    }

    public static func extract_zip(archive_path: String, destination_directory: String) throws {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: archive_path)) else {
            throw NSError(domain: "NativeZipEngine", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to read zip archive file."])
        }

        let standardized_dest = URL(fileURLWithPath: destination_directory).standardizedFileURL.path
        try FileManager.default.createDirectory(atPath: standardized_dest, withIntermediateDirectories: true, attributes: nil)

        if let cd_entries = parse_central_directory(data: data) {
            for entry in cd_entries {
                let sanitized = entry.name.replacingOccurrences(of: "\\", with: "/")
                guard !sanitized.contains("..") else { continue }
                let target_path = (standardized_dest as NSString).appendingPathComponent(sanitized)
                let check_standardized = URL(fileURLWithPath: target_path).standardizedFileURL.path
                guard check_standardized.hasPrefix(standardized_dest) else { continue }

                if entry.is_directory || sanitized.hasSuffix("/") {
                    try? FileManager.default.createDirectory(atPath: target_path, withIntermediateDirectories: true, attributes: nil)
                    continue
                }

                let parent = (target_path as NSString).deletingLastPathComponent
                try? FileManager.default.createDirectory(atPath: parent, withIntermediateDirectories: true, attributes: nil)

                let loc_offset = Int(entry.local_header_offset)
                guard loc_offset + 30 <= data.count else { continue }

                let loc_sig = read_u32(data: data, offset: loc_offset)
                guard loc_sig == 0x04034b50 else { continue }

                let loc_name_len = Int(read_u16(data: data, offset: loc_offset + 26))
                let loc_extra_len = Int(read_u16(data: data, offset: loc_offset + 28))
                let payload_start = loc_offset + 30 + loc_name_len + loc_extra_len
                let payload_end = payload_start + Int(entry.comp_size)
                guard payload_end <= data.count else { continue }

                let payload = data.subdata(in: payload_start..<payload_end)
                let out_data: Data?

                if entry.compression_method == 8 {
                    out_data = inflate_data(payload, uncompressed_size: Int(entry.uncomp_size))
                } else if entry.compression_method == 0 {
                    out_data = payload
                } else {
                    out_data = inflate_data(payload, uncompressed_size: Int(entry.uncomp_size)) ?? payload
                }

                if let valid_data = out_data {
                    try? valid_data.write(to: URL(fileURLWithPath: target_path), options: .atomic)
                }
            }
            return
        }

        try extract_zip_sequential_fallback(data: data, destination_directory: standardized_dest)
    }

    private static func extract_zip_sequential_fallback(data: Data, destination_directory: String) throws {
        var offset = 0
        let total = data.count

        while offset + 30 <= total {
            let sig = read_u32(data: data, offset: offset)
            guard sig == 0x04034b50 else { break }

            let comp_method = read_u16(data: data, offset: offset + 8)
            let comp_size = Int(read_u32(data: data, offset: offset + 18))
            let uncomp_size = Int(read_u32(data: data, offset: offset + 22))
            let name_len = Int(read_u16(data: data, offset: offset + 26))
            let extra_len = Int(read_u16(data: data, offset: offset + 28))

            let name_start = offset + 30
            let name_end = name_start + name_len
            guard name_end <= total else { break }

            let name_bytes = data.subdata(in: name_start..<name_end)
            let file_name = (String(data: name_bytes, encoding: .utf8) ?? "").replacingOccurrences(of: "\\", with: "/")

            let data_start = name_end + extra_len
            let data_end = data_start + comp_size
            guard data_end <= total else { break }

            let raw_data = data.subdata(in: data_start..<data_end)

            if !file_name.isEmpty && !file_name.contains("..") {
                let target_path = (destination_directory as NSString).appendingPathComponent(file_name)
                let check_path = URL(fileURLWithPath: target_path).standardizedFileURL.path
                if check_path.hasPrefix(destination_directory) {
                    if file_name.hasSuffix("/") {
                        try? FileManager.default.createDirectory(atPath: target_path, withIntermediateDirectories: true)
                    } else {
                        let parent = (target_path as NSString).deletingLastPathComponent
                        try? FileManager.default.createDirectory(atPath: parent, withIntermediateDirectories: true)

                        let uncompressed: Data?
                        if comp_method == 8 {
                            uncompressed = inflate_data(raw_data, uncompressed_size: uncomp_size)
                        } else {
                            uncompressed = raw_data
                        }

                        if let out_data = uncompressed {
                            try? out_data.write(to: URL(fileURLWithPath: target_path), options: .atomic)
                        }
                    }
                }
            }

            offset = data_end
        }
    }

    public static func list_zip_entries(archive_path: String) -> [ZipEntryInfo]? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: archive_path)) else { return nil }

        if let cd_entries = parse_central_directory(data: data) {
            return cd_entries.map {
                ZipEntryInfo(
                    name: $0.name,
                    is_directory: $0.is_directory,
                    uncompressed_size: Int64($0.uncomp_size),
                    compressed_size: Int64($0.comp_size),
                    crc32: $0.crc
                )
            }
        }

        var entries: [ZipEntryInfo] = []
        var offset = 0
        let total_count = data.count

        while offset + 30 <= total_count {
            let sig = read_u32(data: data, offset: offset)
            guard sig == 0x04034b50 else { break }

            let crc = read_u32(data: data, offset: offset + 14)
            let comp_size = Int(read_u32(data: data, offset: offset + 18))
            let uncomp_size = Int(read_u32(data: data, offset: offset + 22))
            let name_len = Int(read_u16(data: data, offset: offset + 26))
            let extra_len = Int(read_u16(data: data, offset: offset + 28))

            let name_start = offset + 30
            let name_end = name_start + name_len
            guard name_end <= total_count else { break }

            let name_bytes = data.subdata(in: name_start..<name_end)
            let file_name = String(data: name_bytes, encoding: .utf8) ?? ""
            let is_dir = file_name.hasSuffix("/")

            entries.append(ZipEntryInfo(
                name: file_name,
                is_directory: is_dir,
                uncompressed_size: Int64(uncomp_size),
                compressed_size: Int64(comp_size),
                crc32: crc
            ))

            offset = name_end + extra_len + comp_size
        }

        return entries.isEmpty ? nil : entries
    }

    private struct ParsedCDEntry {
        let name: String
        let is_directory: Bool
        let comp_size: UInt32
        let uncomp_size: UInt32
        let crc: UInt32
        let compression_method: UInt16
        let local_header_offset: UInt32
    }

    private static func parse_central_directory(data: Data) -> [ParsedCDEntry]? {
        let count = data.count
        guard count >= 22 else { return nil }

        let search_start = max(0, count - 65557)
        var eocd_offset: Int? = nil

        var idx = count - 22
        while idx >= search_start {
            if read_u32(data: data, offset: idx) == 0x06054b50 {
                eocd_offset = idx
                break
            }
            idx -= 1
        }

        guard let eocd = eocd_offset else { return nil }

        let total_entries = Int(read_u16(data: data, offset: eocd + 10))
        let cd_offset = Int(read_u32(data: data, offset: eocd + 16))

        guard cd_offset < count else { return nil }

        var results: [ParsedCDEntry] = []
        var cur = cd_offset

        for _ in 0..<total_entries {
            guard cur + 46 <= count else { break }
            let sig = read_u32(data: data, offset: cur)
            guard sig == 0x02014b50 else { break }

            let method = read_u16(data: data, offset: cur + 10)
            let crc = read_u32(data: data, offset: cur + 16)
            let comp_sz = read_u32(data: data, offset: cur + 20)
            let uncomp_sz = read_u32(data: data, offset: cur + 24)
            let name_len = Int(read_u16(data: data, offset: cur + 28))
            let extra_len = Int(read_u16(data: data, offset: cur + 30))
            let comment_len = Int(read_u16(data: data, offset: cur + 32))
            let loc_offset = read_u32(data: data, offset: cur + 42)

            let name_start = cur + 46
            let name_end = name_start + name_len
            guard name_end <= count else { break }

            let name_data = data.subdata(in: name_start..<name_end)
            let file_name = String(data: name_data, encoding: .utf8) ?? ""
            let is_dir = file_name.hasSuffix("/")

            results.append(ParsedCDEntry(
                name: file_name,
                is_directory: is_dir,
                comp_size: comp_sz,
                uncomp_size: uncomp_sz,
                crc: crc,
                compression_method: method,
                local_header_offset: loc_offset
            ))

            cur = 46 + name_len + extra_len + comment_len + cur
        }

        return results.isEmpty ? nil : results
    }

    private static func deflate_data(_ data: Data) -> Data? {
        guard !data.isEmpty else { return Data() }
        var zs = z_stream()
        guard deflateInit2_(&zs, Z_DEFAULT_COMPRESSION, Z_DEFLATED, -MAX_WBITS, 8, Z_DEFAULT_STRATEGY, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            return nil
        }
        defer { deflateEnd(&zs) }

        var output = Data(count: data.count + 128)
        let max_out = output.count

        return data.withUnsafeBytes { in_buf in
            zs.next_in = UnsafeMutablePointer(mutating: in_buf.bindMemory(to: Bytef.self).baseAddress)
            zs.avail_in = uInt(data.count)

            return output.withUnsafeMutableBytes { out_buf in
                zs.next_out = out_buf.bindMemory(to: Bytef.self).baseAddress
                zs.avail_out = uInt(max_out)

                let res = deflate(&zs, Z_FINISH)
                guard res == Z_STREAM_END else { return nil }
                return Data(out_buf.prefix(Int(zs.total_out)))
            }
        }
    }

    private static func inflate_data(_ data: Data, uncompressed_size: Int) -> Data? {
        guard !data.isEmpty else { return Data() }
        var zs = z_stream()
        guard inflateInit2_(&zs, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            return nil
        }
        defer { inflateEnd(&zs) }

        var output = Data()
        let chunk_size = max(uncompressed_size > 0 ? uncompressed_size : 65536, 65536)
        var buffer = [UInt8](repeating: 0, count: chunk_size)

        return data.withUnsafeBytes { in_buf in
            zs.next_in = UnsafeMutablePointer(mutating: in_buf.bindMemory(to: Bytef.self).baseAddress)
            zs.avail_in = uInt(data.count)

            while true {
                let status = buffer.withUnsafeMutableBytes { out_buf -> Int32 in
                    zs.next_out = out_buf.bindMemory(to: Bytef.self).baseAddress
                    zs.avail_out = uInt(chunk_size)
                    let ret = inflate(&zs, Z_NO_FLUSH)
                    let written = chunk_size - Int(zs.avail_out)
                    if written > 0 {
                        output.append(out_buf.baseAddress!.assumingMemoryBound(to: UInt8.self), count: written)
                    }
                    return ret
                }
                if status == Z_STREAM_END {
                    break
                }
                if status != Z_OK {
                    return nil
                }
            }
            return output
        }
    }

    private static func dos_date_time(date: Date = Date()) -> (time: UInt16, date: UInt16) {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let y = UInt16(max(0, (comps.year ?? 2026) - 1980) & 0x7F)
        let m = UInt16((comps.month ?? 1) & 0x0F)
        let d = UInt16((comps.day ?? 1) & 0x1F)
        let date_val = (y << 9) | (m << 5) | d

        let hr = UInt16((comps.hour ?? 0) & 0x1F)
        let min = UInt16((comps.minute ?? 0) & 0x3F)
        let sec = UInt16(((comps.second ?? 0) / 2) & 0x1F)
        let time_val = (hr << 11) | (min << 5) | sec
        return (time_val, date_val)
    }

    private static func read_u16(data: Data, offset: Int) -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        return data.subdata(in: offset..<offset+2).withUnsafeBytes { $0.load(as: UInt16.self) }.littleEndian
    }

    private static func read_u32(data: Data, offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        return data.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian
    }

    private static func append_u16(_ d: inout Data, _ val: UInt16) {
        var v = val.littleEndian
        withUnsafeBytes(of: &v) { d.append(contentsOf: $0) }
    }

    private static func append_u32(_ d: inout Data, _ val: UInt32) {
        var v = val.littleEndian
        withUnsafeBytes(of: &v) { d.append(contentsOf: $0) }
    }
}
