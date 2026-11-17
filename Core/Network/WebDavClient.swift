import Foundation

public final class WebDavClient: NSObject, XMLParserDelegate, @unchecked Sendable {
    public static let shared = WebDavClient()

    private struct ParsedEntry {
        var href = ""
        var is_dir = false
        var size: Int64 = 0
        var mtime = ""
    }

    private var current_entries: [ParsedEntry] = []
    private var current_entry: ParsedEntry?
    private var current_element = ""
    private var current_characters = ""

    public override init() {
        super.init()
    }

    public func list_directory(base_url: URL, path: String, auth: (user: String, pass: String)?) async throws -> [RemoteFileInfo] {
        var target_url = base_url
        if !path.isEmpty && path != "/" {
            let clean_path = path.hasPrefix("/") ? String(path.dropFirst()) : path
            target_url = target_url.appendingPathComponent(clean_path)
        }

        var request = URLRequest(url: target_url)
        request.httpMethod = "PROPFIND"
        request.setValue("1", forHTTPHeaderField: "Depth")
        request.setValue("application/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")

        if let auth = auth, !auth.user.isEmpty {
            let login_string = "\(auth.user):\(auth.pass)"
            if let login_data = login_string.data(using: .utf8) {
                let base64 = login_data.base64EncodedString()
                request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
            }
        }

        let query = """
        <?xml version="1.0" encoding="utf-8"?>
        <D:propfind xmlns:D="DAV:">
          <D:prop>
            <D:resourcetype/>
            <D:getcontentlength/>
            <D:getlastmodified/>
            <D:displayname/>
          </D:prop>
        </D:propfind>
        """
        request.httpBody = query.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http_resp = response as? HTTPURLResponse else {
            throw NSError(domain: "WebDavClient", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
        }

        if http_resp.statusCode != 207 && http_resp.statusCode != 200 {
            throw NSError(domain: "WebDavClient", code: http_resp.statusCode, userInfo: [NSLocalizedDescriptionKey: "WebDAV server responded with status \(http_resp.statusCode)"])
        }

        let parsed = parse_multistatus(data: data)
        var results: [RemoteFileInfo] = []

        let req_path = target_url.path.hasSuffix("/") ? target_url.path : (target_url.path + "/")
        for entry in parsed {
            let entry_href = entry.href.removingPercentEncoding ?? entry.href
            if entry_href == req_path || entry_href == target_url.path || entry_href.trimmingCharacters(in: CharacterSet(charactersIn: "/")).isEmpty {
                continue
            }

            let name = (entry_href as NSString).lastPathComponent
            if name.isEmpty || name == "." || name == ".." { continue }

            results.append(RemoteFileInfo(
                name: name,
                is_directory: entry.is_dir,
                size: entry.size,
                raw_line: "\(entry.is_dir ? "d" : "-") \(entry.size) \(entry.mtime) \(name)"
            ))
        }

        return results
    }

    public func download_file(url: URL, destination: String, auth: (user: String, pass: String)?) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let auth = auth, !auth.user.isEmpty {
            let login_string = "\(auth.user):\(auth.pass)"
            if let login_data = login_string.data(using: .utf8) {
                let base64 = login_data.base64EncodedString()
                request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
            }
        }

        let (temp_url, response) = try await URLSession.shared.download(for: request)
        guard let http_resp = response as? HTTPURLResponse, http_resp.statusCode < 400 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 500
            throw NSError(domain: "WebDavClient", code: code, userInfo: [NSLocalizedDescriptionKey: "Download failed with HTTP \(code)"])
        }

        if FileManager.default.fileExists(atPath: destination) {
            try FileManager.default.removeItem(atPath: destination)
        }
        try FileManager.default.moveItem(at: temp_url, to: URL(fileURLWithPath: destination))
    }

    public func upload_file(url: URL, source_path: String, auth: (user: String, pass: String)?) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        if let auth = auth, !auth.user.isEmpty {
            let login_string = "\(auth.user):\(auth.pass)"
            if let login_data = login_string.data(using: .utf8) {
                let base64 = login_data.base64EncodedString()
                request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
            }
        }

        let file_data = try Data(contentsOf: URL(fileURLWithPath: source_path))
        let (_, response) = try await URLSession.shared.upload(for: request, from: file_data)
        guard let http_resp = response as? HTTPURLResponse, http_resp.statusCode < 400 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 500
            throw NSError(domain: "WebDavClient", code: code, userInfo: [NSLocalizedDescriptionKey: "Upload failed with HTTP \(code)"])
        }
    }

    public func create_directory(url: URL, auth: (user: String, pass: String)?) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "MKCOL"
        if let auth = auth, !auth.user.isEmpty {
            let login_string = "\(auth.user):\(auth.pass)"
            if let login_data = login_string.data(using: .utf8) {
                let base64 = login_data.base64EncodedString()
                request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
            }
        }

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http_resp = response as? HTTPURLResponse, (http_resp.statusCode == 201 || http_resp.statusCode == 200) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 500
            throw NSError(domain: "WebDavClient", code: code, userInfo: [NSLocalizedDescriptionKey: "MKCOL failed with HTTP \(code)"])
        }
    }

    public func delete_item(url: URL, auth: (user: String, pass: String)?) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if let auth = auth, !auth.user.isEmpty {
            let login_string = "\(auth.user):\(auth.pass)"
            if let login_data = login_string.data(using: .utf8) {
                let base64 = login_data.base64EncodedString()
                request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
            }
        }

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http_resp = response as? HTTPURLResponse, (http_resp.statusCode == 200 || http_resp.statusCode == 204) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 500
            throw NSError(domain: "WebDavClient", code: code, userInfo: [NSLocalizedDescriptionKey: "DELETE failed with HTTP \(code)"])
        }
    }

    private func parse_multistatus(data: Data) -> [ParsedEntry] {
        current_entries.removeAll()
        current_entry = nil
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return current_entries
    }

    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        let tag = elementName.components(separatedBy: ":").last?.lowercased() ?? elementName.lowercased()
        current_element = tag
        current_characters = ""
        if tag == "response" {
            current_entry = ParsedEntry()
        } else if tag == "collection" {
            current_entry?.is_dir = true
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        current_characters += string
    }

    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let tag = elementName.components(separatedBy: ":").last?.lowercased() ?? elementName.lowercased()
        let text = current_characters.trimmingCharacters(in: .whitespacesAndNewlines)
        if tag == "response" {
            if let entry = current_entry {
                current_entries.append(entry)
            }
            current_entry = nil
        } else if tag == "href" {
            current_entry?.href = text
        } else if tag == "getcontentlength" {
            current_entry?.size = Int64(text) ?? 0
        } else if tag == "getlastmodified" {
            current_entry?.mtime = text
        }
    }
}
