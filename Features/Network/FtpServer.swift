import Foundation
import Darwin
import UIKit

public final class FtpServer: @unchecked Sendable {
    public static let shared = FtpServer()

    private var server_fd: Int32 = -1
    private var read_source: DispatchSourceRead?
    private let server_queue = DispatchQueue(label: "io.github.abdurazaaqmohammed.ftpserver", attributes: .concurrent)
    private var bg_task_id: UIBackgroundTaskIdentifier = .invalid

    public private(set) var is_running = false
    public var port: UInt16 = 2121
    public var root_directory: String = "/var/mobile"
    public var allow_anonymous: Bool = true
    public var required_username: String = "admin"
    public var required_password: String = "admin"

    public var on_log_message: ((String) -> Void)?
    public var on_client_count_changed: ((Int) -> Void)?

    private var active_client_count: Int = 0 {
        didSet {
            let count = active_client_count
            DispatchQueue.main.async { [weak self] in
                self?.on_client_count_changed?(count)
            }
        }
    }

    private init() {}

    public func start(port: UInt16 = 2121, root: String = "/var/mobile") throws {
        guard !is_running else { return }
        self.port = port
        self.root_directory = root

        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Failed to create FTP socket: \(errno)"])
        }

        var opt: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &opt, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = in_addr_t(0)

        let bind_res = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bind_res == 0 else {
            let err = errno
            close(fd)
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(err), userInfo: [NSLocalizedDescriptionKey: "FTP bind failed on port \(port): errno \(err)"])
        }

        guard listen(fd, 16) == 0 else {
            let err = errno
            close(fd)
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(err), userInfo: [NSLocalizedDescriptionKey: "FTP listen failed: errno \(err)"])
        }

        self.server_fd = fd
        self.is_running = true

        begin_background_task()

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: server_queue)
        source.setEventHandler { [weak self] in
            self?.accept_connection()
        }
        source.setCancelHandler {
            close(fd)
        }
        self.read_source = source
        source.resume()

        log("[FTP] Server started on port \(port), root: \(root)")
    }

    public func stop() {
        guard is_running else { return }
        is_running = false

        read_source?.cancel()
        read_source = nil
        server_fd = -1

        end_background_task()
        log("[FTP] Server stopped")
    }

    private func accept_connection() {
        var client_addr = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let client_fd = withUnsafeMutablePointer(to: &client_addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                accept(server_fd, $0, &len)
            }
        }

        guard client_fd >= 0 else { return }

        var opt: Int32 = 1
        setsockopt(client_fd, SOL_SOCKET, SO_NOSIGPIPE, &opt, socklen_t(MemoryLayout<Int32>.size))

        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        getnameinfo(withUnsafePointer(to: &client_addr) { UnsafeRawPointer($0).assumingMemoryBound(to: sockaddr.self) },
                    len, &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
        let client_ip = String(cString: hostname)

        active_client_count += 1
        log("[FTP] Client connected from \(client_ip)")

        server_queue.async { [weak self] in
            self?.handle_ftp_session(client_fd: client_fd, client_ip: client_ip)
            self?.active_client_count -= 1
            self?.log("[FTP] Client \(client_ip) disconnected")
        }
    }

    private func handle_ftp_session(client_fd: Int32, client_ip: String) {
        defer { close(client_fd) }

        send_response(client_fd, "220 MP Manager iOS FTP Server ready\r\n")

        var is_authenticated = allow_anonymous
        var current_user = allow_anonymous ? "anonymous" : ""
        var working_dir = root_directory
        var rename_from: String? = nil
        var passive_fd: Int32 = -1
        var active_addr: sockaddr_in? = nil

        var buffer = [UInt8](repeating: 0, count: 4096)
        var line_buffer = ""

        while is_running {
            let n = recv(client_fd, &buffer, buffer.count, 0)
            if n <= 0 { break }

            guard let text = String(bytes: buffer[0..<n], encoding: .utf8) ?? String(bytes: buffer[0..<n], encoding: .ascii) else {
                continue
            }
            line_buffer += text

            while let r_range = line_buffer.range(of: "\r\n") ?? line_buffer.range(of: "\n") {
                let cmd_line = String(line_buffer[..<r_range.lowerBound]).trimmingCharacters(in: .whitespaces)
                line_buffer.removeSubrange(..<r_range.upperBound)

                if cmd_line.isEmpty { continue }

                let parts = cmd_line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                let verb = parts[0].uppercased()
                let arg = parts.count > 1 ? String(parts[1]) : ""

                switch verb {
                case "USER":
                    current_user = arg
                    if allow_anonymous && (arg.lowercased() == "anonymous" || arg.isEmpty) {
                        is_authenticated = true
                        send_response(client_fd, "230 User logged in, proceed\r\n")
                    } else {
                        send_response(client_fd, "331 Password required for \(arg)\r\n")
                    }

                case "PASS":
                    if allow_anonymous || (current_user == required_username && arg == required_password) {
                        is_authenticated = true
                        send_response(client_fd, "230 User logged in, proceed\r\n")
                    } else {
                        send_response(client_fd, "530 Login incorrect\r\n")
                    }

                case "QUIT":
                    send_response(client_fd, "221 Goodbye\r\n")
                    return

                case "NOOP":
                    send_response(client_fd, "200 OK\r\n")

                case "SYST":
                    send_response(client_fd, "215 UNIX Type: L8\r\n")

                case "FEAT":
                    let feat = "211-Features:\r\n UTF8\r\n SIZE\r\n MDTM\r\n PASV\r\n EPSV\r\n REST STREAM\r\n211 End\r\n"
                    send_response(client_fd, feat)

                case "OPTS":
                    send_response(client_fd, "200 OPTS command successful\r\n")

                case "PWD":
                    guard is_authenticated else { send_not_logged_in(client_fd); break }
                    send_response(client_fd, "257 \"\(working_dir)\" is the current directory\r\n")

                case "CWD":
                    guard is_authenticated else { send_not_logged_in(client_fd); break }
                    let target = resolve_path(working_dir: working_dir, path: arg)
                    var st = stat()
                    if stat(target, &st) == 0 && (st.st_mode & S_IFMT) == S_IFDIR {
                        working_dir = target
                        send_response(client_fd, "250 Directory changed to \"\(working_dir)\"\r\n")
                    } else {
                        send_response(client_fd, "550 Directory not found\r\n")
                    }

                case "CDUP":
                    guard is_authenticated else { send_not_logged_in(client_fd); break }
                    working_dir = (working_dir as NSString).deletingLastPathComponent
                    if working_dir.isEmpty { working_dir = "/" }
                    send_response(client_fd, "250 Directory changed to \"\(working_dir)\"\r\n")

                case "TYPE":
                    send_response(client_fd, "200 Type set to \(arg)\r\n")

                case "PASV":
                    guard is_authenticated else { send_not_logged_in(client_fd); break }
                    if passive_fd >= 0 { close(passive_fd); passive_fd = -1 }
                    if let (p_fd, p_port) = create_passive_listener() {
                        passive_fd = p_fd
                        let host_ip = get_wifi_address() ?? "127.0.0.1"
                        let ip_parts = host_ip.split(separator: ".")
                        if ip_parts.count == 4 {
                            let p1 = p_port / 256
                            let p2 = p_port % 256
                            let h = ip_parts.joined(separator: ",")
                            send_response(client_fd, "227 Entering Passive Mode (\(h),\(p1),\(p2))\r\n")
                        } else {
                            send_response(client_fd, "500 Failed to determine host IP\r\n")
                        }
                    } else {
                        send_response(client_fd, "500 Failed to enter passive mode\r\n")
                    }

                case "EPSV":
                    guard is_authenticated else { send_not_logged_in(client_fd); break }
                    if passive_fd >= 0 { close(passive_fd); passive_fd = -1 }
                    if let (p_fd, p_port) = create_passive_listener() {
                        passive_fd = p_fd
                        send_response(client_fd, "229 Entering Extended Passive Mode (|||\(p_port)|)\r\n")
                    } else {
                        send_response(client_fd, "500 Failed to enter EPSV\r\n")
                    }

                case "PORT":
                    guard is_authenticated else { send_not_logged_in(client_fd); break }
                    let nums = arg.split(separator: ",").compactMap { Int($0) }
                    if nums.count == 6 {
                        let ip_str = "\(nums[0]).\(nums[1]).\(nums[2]).\(nums[3])"
                        let port_val = UInt16(nums[4] * 256 + nums[5])
                        var a = sockaddr_in()
                        a.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                        a.sin_family = sa_family_t(AF_INET)
                        a.sin_port = in_port_t(port_val).bigEndian
                        inet_pton(AF_INET, ip_str, &a.sin_addr)
                        active_addr = a
                        send_response(client_fd, "200 PORT command successful\r\n")
                    } else {
                        send_response(client_fd, "501 Syntax error in PORT\r\n")
                    }

                case "LIST":
                    guard is_authenticated else { send_not_logged_in(client_fd); break }
                    let target = arg.isEmpty ? working_dir : resolve_path(working_dir: working_dir, path: arg)
                    let data_conn = open_data_connection(passive_fd: &passive_fd, active_addr: active_addr)
                    if data_conn >= 0 {
                        send_response(client_fd, "150 Opening ASCII mode data connection for file list\r\n")
                        send_directory_listing(data_fd: data_conn, dir_path: target)
                        close(data_conn)
                        send_response(client_fd, "226 Transfer complete\r\n")
                    } else {
                        send_response(client_fd, "425 Can't open data connection\r\n")
                    }

                case "NLST":
                    guard is_authenticated else { send_not_logged_in(client_fd); break }
                    let target = arg.isEmpty ? working_dir : resolve_path(working_dir: working_dir, path: arg)
                    let data_conn = open_data_connection(passive_fd: &passive_fd, active_addr: active_addr)
                    if data_conn >= 0 {
                        send_response(client_fd, "150 Opening ASCII mode data connection for file names\r\n")
                        send_directory_names(data_fd: data_conn, dir_path: target)
                        close(data_conn)
                        send_response(client_fd, "226 Transfer complete\r\n")
                    } else {
                        send_response(client_fd, "425 Can't open data connection\r\n")
                    }

                case "SIZE":
                    guard is_authenticated else { send_not_logged_in(client_fd); break }
                    let target = resolve_path(working_dir: working_dir, path: arg)
                    var st = stat()
                    if stat(target, &st) == 0 && (st.st_mode & S_IFMT) != S_IFDIR {
                        send_response(client_fd, "213 \(st.st_size)\r\n")
                    } else {
                        send_response(client_fd, "550 Could not get file size\r\n")
                    }

                case "MDTM":
                    guard is_authenticated else { send_not_logged_in(client_fd); break }
                    let target = resolve_path(working_dir: working_dir, path: arg)
                    var st = stat()
                    if stat(target, &st) == 0 {
                        let df = DateFormatter()
                        df.dateFormat = "yyyyMMddHHmmss"
                        df.timeZone = TimeZone(secondsFromGMT: 0)
                        let d_str = df.string(from: Date(timeIntervalSince1970: TimeInterval(st.st_mtimespec.tv_sec)))
                        send_response(client_fd, "213 \(d_str)\r\n")
                    } else {
                        send_response(client_fd, "550 Could not get file timestamp\r\n")
                    }

                case "RETR":
                    guard is_authenticated else { send_not_logged_in(client_fd); break }
                    let target = resolve_path(working_dir: working_dir, path: arg)
                    guard let file_handle = FileHandle(forReadingAtPath: target) else {
                        send_response(client_fd, "550 File not found or unreadable\r\n")
                        break
                    }
                    let data_conn = open_data_connection(passive_fd: &passive_fd, active_addr: active_addr)
                    if data_conn >= 0 {
                        send_response(client_fd, "150 Opening BINARY mode data connection for \(arg)\r\n")
                        while true {
                            let chunk = file_handle.readData(ofLength: 65536)
                            if chunk.isEmpty { break }
                            chunk.withUnsafeBytes { ptr in
                                _ = send(data_conn, ptr.baseAddress!, chunk.count, 0)
                            }
                        }
                        try? file_handle.close()
                        close(data_conn)
                        send_response(client_fd, "226 Transfer complete\r\n")
                        log("[FTP] Downloaded \(target)")
                    } else {
                        try? file_handle.close()
                        send_response(client_fd, "425 Can't open data connection\r\n")
                    }

                case "STOR":
                    guard is_authenticated else { send_not_logged_in(client_fd); break }
                    let target = resolve_path(working_dir: working_dir, path: arg)
                    if FileManager.default.fileExists(atPath: target) {
                        try? FileManager.default.removeItem(atPath: target)
                    }
                    guard FileManager.default.createFile(atPath: target, contents: nil, attributes: nil),
                          let file_handle = FileHandle(forWritingAtPath: target) else {
                        send_response(client_fd, "550 Cannot create target file\r\n")
                        break
                    }
                    let data_conn = open_data_connection(passive_fd: &passive_fd, active_addr: active_addr)
                    if data_conn >= 0 {
                        send_response(client_fd, "150 Opening BINARY mode data connection for \(arg)\r\n")
                        var stream_buf = [UInt8](repeating: 0, count: 65536)
                        while true {
                            let count = recv(data_conn, &stream_buf, stream_buf.count, 0)
                            if count <= 0 { break }
                            file_handle.write(Data(stream_buf[0..<count]))
                        }
                        try? file_handle.close()
                        close(data_conn)
                        send_response(client_fd, "226 Transfer complete\r\n")
                        log("[FTP] Uploaded \(target)")
                    } else {
                        try? file_handle.close()
                        send_response(client_fd, "425 Can't open data connection\r\n")
                    }

                case "DELE":
                    guard is_authenticated else { send_not_logged_in(client_fd); break }
                    let target = resolve_path(working_dir: working_dir, path: arg)
                    if unlink(target) == 0 {
                        send_response(client_fd, "250 File deleted\r\n")
                        log("[FTP] Deleted \(target)")
                    } else {
                        send_response(client_fd, "550 Delete failed: errno \(errno)\r\n")
                    }

                case "RMD":
                    guard is_authenticated else { send_not_logged_in(client_fd); break }
                    let target = resolve_path(working_dir: working_dir, path: arg)
                    if rmdir(target) == 0 {
                        send_response(client_fd, "250 Directory removed\r\n")
                    } else {
                        send_response(client_fd, "550 Remove directory failed\r\n")
                    }

                case "MKD":
                    guard is_authenticated else { send_not_logged_in(client_fd); break }
                    let target = resolve_path(working_dir: working_dir, path: arg)
                    if mkdir(target, 0o755) == 0 {
                        send_response(client_fd, "257 \"\(target)\" created\r\n")
                    } else {
                        send_response(client_fd, "550 Create directory failed\r\n")
                    }

                case "RNFR":
                    guard is_authenticated else { send_not_logged_in(client_fd); break }
                    let target = resolve_path(working_dir: working_dir, path: arg)
                    if FileManager.default.fileExists(atPath: target) {
                        rename_from = target
                        send_response(client_fd, "350 Ready for RNTO\r\n")
                    } else {
                        send_response(client_fd, "550 File not found\r\n")
                    }

                case "RNTO":
                    guard is_authenticated else { send_not_logged_in(client_fd); break }
                    guard let src = rename_from else {
                        send_response(client_fd, "503 Bad sequence of commands\r\n")
                        break
                    }
                    let dst = resolve_path(working_dir: working_dir, path: arg)
                    if rename(src, dst) == 0 {
                        rename_from = nil
                        send_response(client_fd, "250 Rename successful\r\n")
                    } else {
                        send_response(client_fd, "550 Rename failed\r\n")
                    }

                default:
                    send_response(client_fd, "502 Command not implemented: \(verb)\r\n")
                }
            }
        }

        if passive_fd >= 0 { close(passive_fd) }
    }

    private func send_response(_ client_fd: Int32, _ str: String) {
        _ = str.withCString { send(client_fd, $0, strlen($0), 0) }
    }

    private func send_not_logged_in(_ client_fd: Int32) {
        send_response(client_fd, "530 Please login with USER and PASS\r\n")
    }

    private func resolve_path(working_dir: String, path: String) -> String {
        if path.hasPrefix("/") {
            return (path as NSString).standardizingPath
        }
        return ((working_dir as NSString).appendingPathComponent(path) as NSString).standardizingPath
    }

    private func create_passive_listener() -> (fd: Int32, port: UInt16)? {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }

        var opt: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &opt, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.s_addr = in_addr_t(0)

        let bind_res = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bind_res == 0, listen(fd, 1) == 0 else {
            close(fd)
            return nil
        }

        var bound_addr = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let name_res = withUnsafeMutablePointer(to: &bound_addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &len)
            }
        }
        guard name_res == 0 else {
            close(fd)
            return nil
        }

        let assigned_port = UInt16(bigEndian: bound_addr.sin_port)
        return (fd, assigned_port)
    }

    private func open_data_connection(passive_fd: inout Int32, active_addr: sockaddr_in?) -> Int32 {
        if passive_fd >= 0 {
            var client_addr = sockaddr_in()
            var len = socklen_t(MemoryLayout<sockaddr_in>.size)
            let data_fd = withUnsafeMutablePointer(to: &client_addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(passive_fd, $0, &len)
                }
            }
            close(passive_fd)
            passive_fd = -1
            return data_fd
        }

        if var target_addr = active_addr {
            let data_fd = socket(AF_INET, SOCK_STREAM, 0)
            guard data_fd >= 0 else { return -1 }
            var opt: Int32 = 1
            setsockopt(data_fd, SOL_SOCKET, SO_NOSIGPIPE, &opt, socklen_t(MemoryLayout<Int32>.size))
            let connect_res = withUnsafePointer(to: &target_addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    connect(data_fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            if connect_res == 0 {
                return data_fd
            } else {
                close(data_fd)
                return -1
            }
        }

        return -1
    }

    private func send_directory_listing(data_fd: Int32, dir_path: String) {
        guard let dir = opendir(dir_path) else { return }
        defer { closedir(dir) }

        var output = ""
        while let entry = readdir(dir) {
            let name = withUnsafePointer(to: &entry.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(entry.pointee.d_namlen)) {
                    String(cString: $0)
                }
            }
            if name == "." || name == ".." { continue }

            let item_path = (dir_path as NSString).appendingPathComponent(name)
            var st = stat()
            if lstat(item_path, &st) == 0 {
                let is_dir = (st.st_mode & S_IFMT) == S_IFDIR
                let type_char = is_dir ? "d" : "-"
                let rwx = format_permissions(st.st_mode)
                let df = DateFormatter()
                df.dateFormat = "MMM dd HH:mm"
                let date_str = df.string(from: Date(timeIntervalSince1970: TimeInterval(st.st_mtimespec.tv_sec)))
                let line = "\(type_char)\(rwx) 1 mobile staff \(st.st_size) \(date_str) \(name)\r\n"
                output += line
            }
        }

        _ = output.withCString { send(data_fd, $0, strlen($0), 0) }
    }

    private func send_directory_names(data_fd: Int32, dir_path: String) {
        guard let dir = opendir(dir_path) else { return }
        defer { closedir(dir) }

        var output = ""
        while let entry = readdir(dir) {
            let name = withUnsafePointer(to: &entry.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(entry.pointee.d_namlen)) {
                    String(cString: $0)
                }
            }
            if name == "." || name == ".." { continue }
            output += "\(name)\r\n"
        }
        _ = output.withCString { send(data_fd, $0, strlen($0), 0) }
    }

    private func format_permissions(_ mode: mode_t) -> String {
        let u_r = (mode & S_IRUSR) != 0 ? "r" : "-"
        let u_w = (mode & S_IWUSR) != 0 ? "w" : "-"
        let u_x = (mode & S_IXUSR) != 0 ? "x" : "-"
        let g_r = (mode & S_IRGRP) != 0 ? "r" : "-"
        let g_w = (mode & S_IWGRP) != 0 ? "w" : "-"
        let g_x = (mode & S_IXGRP) != 0 ? "x" : "-"
        let o_r = (mode & S_IROTH) != 0 ? "r" : "-"
        let o_w = (mode & S_IWOTH) != 0 ? "w" : "-"
        let o_x = (mode & S_IXOTH) != 0 ? "x" : "-"
        return "\(u_r)\(u_w)\(u_x)\(g_r)\(g_w)\(g_x)\(o_r)\(o_w)\(o_x)"
    }

    private func begin_background_task() {
        if bg_task_id == .invalid {
            bg_task_id = UIApplication.shared.beginBackgroundTask(withName: "MPManager.FtpServer") { [weak self] in
                self?.end_background_task()
            }
        }
    }

    private func end_background_task() {
        if bg_task_id != .invalid {
            UIApplication.shared.endBackgroundTask(bg_task_id)
            bg_task_id = .invalid
        }
    }

    private func log(_ msg: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(msg)"
        DispatchQueue.main.async { [weak self] in
            self?.on_log_message?(line)
        }
    }

    public func get_wifi_address() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first_addr = ifaddr else { return nil }
        var ptr: UnsafeMutablePointer<ifaddrs>? = first_addr
        while ptr != nil {
            let interface = ptr!.pointee
            let addr_family = interface.ifa_addr.pointee.sa_family
            if addr_family == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                    break
                }
            }
            ptr = interface.ifa_next
        }
        freeifaddrs(first_addr)
        return address
    }
}
