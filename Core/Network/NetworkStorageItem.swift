import Foundation

public enum NetworkProtocol: String, Codable, CaseIterable, Sendable {
    case ftp = "FTP"
    case ftps = "FTPS"
    case sftp = "SFTP"
    case webdav = "WebDAV"
    case smb = "SMB2/3"
}

public struct NetworkStorageItem: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var proto: NetworkProtocol
    public var host: String
    public var port: Int
    public var path: String
    public var username: String

    public var default_port: Int {
        switch proto {
        case .ftp: return 21
        case .ftps: return 990
        case .sftp: return 22
        case .webdav: return 80
        case .smb: return 445
        }
    }

    public init(id: UUID = UUID(), name: String, proto: NetworkProtocol, host: String, port: Int? = nil, path: String = "/", username: String = "") {
        self.id = id
        self.name = name
        self.proto = proto
        self.host = host
        self.port = port ?? 21
        self.path = path
        self.username = username
    }
}
