import Foundation
import Darwin

public actor FileOperationsQueue {
    public static let shared = FileOperationsQueue()

    private var active_tasks: [UUID: Task<Void, Error>] = [:]
    private var delegates: [UUID: any FileOperationDelegate] = [:]

    private init() {}

    public func register_delegate(_ delegate: any FileOperationDelegate, for operation_id: UUID) {
        delegates[operation_id] = delegate
    }

    public func cancel_operation(_ operation_id: UUID) {
        active_tasks[operation_id]?.cancel()
        active_tasks.removeValue(forKey: operation_id)
        delegates.removeValue(forKey: operation_id)
    }

    public func copy_items(
        sources: [String],
        destination_directory: String,
        conflict_resolution: ConflictResolution = .keepBoth
    ) async throws -> UUID {
        let op_id = UUID()
        let task = Task.detached(priority: .userInitiated) {
            var total_bytes: Int64 = 0
            for src in sources {
                total_bytes += self.calculate_total_size(at: src)
            }

            var bytes_completed: Int64 = 0

            for src in sources {
                try Task.checkCancellation()
                guard let target = ConflictResolver.resolve_destination(
                    source: src,
                    destination_directory: destination_directory,
                    resolution: conflict_resolution
                ) else {
                    continue
                }

                try self.copy_recursive(
                    source: src,
                    destination: target,
                    op_id: op_id,
                    total_bytes: total_bytes,
                    bytes_completed: &bytes_completed
                )
            }
        }

        active_tasks[op_id] = task
        try await task.value
        active_tasks.removeValue(forKey: op_id)
        delegates.removeValue(forKey: op_id)
        return op_id
    }

    public func move_items(
        sources: [String],
        destination_directory: String,
        conflict_resolution: ConflictResolution = .keepBoth
    ) async throws -> UUID {
        let op_id = UUID()
        let task = Task.detached(priority: .userInitiated) {
            var total_bytes: Int64 = 0
            for src in sources {
                total_bytes += self.calculate_total_size(at: src)
            }

            var bytes_completed: Int64 = 0

            for src in sources {
                try Task.checkCancellation()
                guard let target = ConflictResolver.resolve_destination(
                    source: src,
                    destination_directory: destination_directory,
                    resolution: conflict_resolution
                ) else {
                    continue
                }

                let filename = (src as NSString).lastPathComponent
                let src_c = (src as NSString).fileSystemRepresentation
                let dst_c = (target as NSString).fileSystemRepresentation

                if rename(src_c, dst_c) == 0 {
                    bytes_completed += self.calculate_total_size(at: target)
                    self.report_progress(op_id: op_id, type: .move, current_item: filename, completed: bytes_completed, total: total_bytes)
                    continue
                }

                try self.copy_recursive(
                    source: src,
                    destination: target,
                    op_id: op_id,
                    total_bytes: total_bytes,
                    bytes_completed: &bytes_completed
                )
                try self.delete_internal(path: src)
            }
        }

        active_tasks[op_id] = task
        try await task.value
        active_tasks.removeValue(forKey: op_id)
        delegates.removeValue(forKey: op_id)
        return op_id
    }

    public func delete(paths: [String]) async throws -> UUID {
        let op_id = UUID()
        let task = Task.detached(priority: .userInitiated) {
            let total = Int64(paths.count)
            var count: Int64 = 0
            for path in paths {
                try Task.checkCancellation()
                guard self.is_safe_to_delete(path: path) else {
                    throw NSError(
                        domain: "FileOperationsQueue",
                        code: 403,
                        userInfo: [NSLocalizedDescriptionKey: "Protected system path cannot be deleted: \(path)"]
                    )
                }
                try self.delete_internal(path: path)
                count += 1
                self.report_progress(op_id: op_id, type: .delete, current_item: (path as NSString).lastPathComponent, completed: count, total: total)
            }
        }

        active_tasks[op_id] = task
        try await task.value
        active_tasks.removeValue(forKey: op_id)
        delegates.removeValue(forKey: op_id)
        return op_id
    }

    public nonisolated func rename_item(at path: String, to new_name: String) throws {
        let parent = (path as NSString).deletingLastPathComponent
        let target = (parent as NSString).appendingPathComponent(new_name)
        if FileManager.default.fileExists(atPath: target) {
            throw NSError(domain: "FileOperationsQueue", code: 409, userInfo: [NSLocalizedDescriptionKey: "An item named '\(new_name)' already exists."])
        }
        let rc = rename((path as NSString).fileSystemRepresentation, (target as NSString).fileSystemRepresentation)
        if rc != 0 {
            let err = errno
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(err), userInfo: [NSLocalizedDescriptionKey: "Rename failed: \(String(cString: strerror(err)))"])
        }
    }

    private nonisolated func is_safe_to_delete(path: String) -> Bool {
        let clean = (path as NSString).standardizingPath
        let forbidden: Set<String> = [
            "/", "/var", "/var/mobile", "/var/jb", "/private", "/System", "/Library",
            "/Applications", "/usr", "/bin", "/sbin", "/etc", "/dev", "/Volumes"
        ]
        if forbidden.contains(clean) { return false }
        return true
    }

    private nonisolated func delete_internal(path: String) throws {
        try PrivilegeManager.delete_item(at: path)
    }

    private nonisolated func calculate_total_size(at path: String) -> Int64 {
        var stat_info = stat()
        guard lstat((path as NSString).fileSystemRepresentation, &stat_info) == 0 else { return 0 }
        if (stat_info.st_mode & S_IFMT) != S_IFDIR {
            return Int64(stat_info.st_size)
        }
        var total: Int64 = 0
        if let enumerator = FileManager.default.enumerator(atPath: path) {
            while let file = enumerator.nextObject() as? String {
                let full = (path as NSString).appendingPathComponent(file)
                if lstat((full as NSString).fileSystemRepresentation, &stat_info) == 0 {
                    if (stat_info.st_mode & S_IFMT) != S_IFDIR {
                        total += Int64(stat_info.st_size)
                    }
                }
            }
        }
        return total
    }

    private nonisolated func copy_recursive(
        source: String,
        destination: String,
        op_id: UUID,
        total_bytes: Int64,
        bytes_completed: inout Int64
    ) throws {
        var stat_info = stat()
        guard lstat((source as NSString).fileSystemRepresentation, &stat_info) == 0 else { return }

        if (stat_info.st_mode & S_IFMT) == S_IFDIR {
            try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
            chmod((destination as NSString).fileSystemRepresentation, stat_info.st_mode)

            guard let dir = opendir((source as NSString).fileSystemRepresentation) else { return }
            defer { closedir(dir) }

            while let entry = readdir(dir) {
                let name = withUnsafeBytes(of: entry.pointee.d_name) { raw_ptr -> String in
                    guard let base = raw_ptr.baseAddress else { return "" }
                    return String(cString: base.assumingMemoryBound(to: CChar.self))
                }
                if name == "." || name == ".." { continue }

                let sub_src = (source as NSString).appendingPathComponent(name)
                let sub_dst = (destination as NSString).appendingPathComponent(name)
                try copy_recursive(source: sub_src, destination: sub_dst, op_id: op_id, total_bytes: total_bytes, bytes_completed: &bytes_completed)
            }
        } else if (stat_info.st_mode & S_IFMT) == S_IFLNK {
            var buffer = [CChar](repeating: 0, count: 1024)
            let len = readlink((source as NSString).fileSystemRepresentation, &buffer, 1023)
            if len > 0 {
                buffer[len] = 0
                symlink(buffer, (destination as NSString).fileSystemRepresentation)
            }
        } else {
            guard let in_stream = InputStream(fileAtPath: source),
                  let out_stream = OutputStream(toFileAtPath: destination, append: false) else {
                throw NSError(domain: "FileOperationsQueue", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to open stream for \(source) -> \(destination)"])
            }

            in_stream.open()
            out_stream.open()
            defer {
                in_stream.close()
                out_stream.close()
            }

            let buffer_size = 65536
            var buffer = [UInt8](repeating: 0, count: buffer_size)

            while in_stream.hasBytesAvailable {
                try Task.checkCancellation()
                let read = in_stream.read(&buffer, maxLength: buffer_size)
                if read < 0 {
                    throw in_stream.streamError ?? NSError(domain: "FileOperationsQueue", code: 3, userInfo: nil)
                }
                if read == 0 { break }

                var written = 0
                while written < read {
                    let write_count = out_stream.write(&buffer[written], maxLength: read - written)
                    if write_count <= 0 {
                        throw out_stream.streamError ?? NSError(domain: "FileOperationsQueue", code: 4, userInfo: nil)
                    }
                    written += write_count
                }

                bytes_completed += Int64(read)
                report_progress(
                    op_id: op_id,
                    type: .copy,
                    current_item: (source as NSString).lastPathComponent,
                    completed: bytes_completed,
                    total: total_bytes
                )
            }

            chmod((destination as NSString).fileSystemRepresentation, stat_info.st_mode)
        }
    }

    private nonisolated func report_progress(
        op_id: UUID,
        type: OperationType,
        current_item: String,
        completed: Int64,
        total: Int64
    ) {
        let p = OperationProgress(
            operation_id: op_id,
            type: type,
            current_item: current_item,
            completed_units: completed,
            total_units: total
        )
        Task { [weak self] in
            guard let self = self else { return }
            let d = await self.delegates[op_id]
            d?.operation_did_update_progress(p)
        }
    }
}
