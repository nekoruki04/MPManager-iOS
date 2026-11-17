import Foundation
import Darwin

public struct SearchQuery: Sendable {
    public let root_path: String
    public let name_query: String
    public let match_case: Bool
    public let is_regex: Bool
    public let content_query: String?
    public let min_size: Int64?
    public let max_size: Int64?

    public init(
        root_path: String,
        name_query: String,
        match_case: Bool = false,
        is_regex: Bool = false,
        content_query: String? = nil,
        min_size: Int64? = nil,
        max_size: Int64? = nil
    ) {
        self.root_path = root_path
        self.name_query = name_query
        self.match_case = match_case
        self.is_regex = is_regex
        self.content_query = content_query
        self.min_size = min_size
        self.max_size = max_size
    }
}

public final class FileSearchEngine: Sendable {
    public static let shared = FileSearchEngine()

    public init() {}

    public func execute_search(query: SearchQuery) async -> [FileItem] {
        return await Task.detached(priority: .userInitiated) {
            var results: [FileItem] = []
            var regex: NSRegularExpression? = nil
            if query.is_regex && !query.name_query.isEmpty {
                let options: NSRegularExpression.Options = query.match_case ? [] : [.caseInsensitive]
                regex = try? NSRegularExpression(pattern: query.name_query, options: options)
            }

            self.search_recursive(
                directory: query.root_path,
                query: query,
                regex: regex,
                results: &results
            )
            return results
        }.value
    }

    private func search_recursive(
        directory: String,
        query: SearchQuery,
        regex: NSRegularExpression?,
        results: inout [FileItem]
    ) {
        guard let dir = opendir((directory as NSString).fileSystemRepresentation) else { return }
        defer { closedir(dir) }

        while let entry = readdir(dir) {
            let name = withUnsafeBytes(of: entry.pointee.d_name) { raw_ptr -> String in
                guard let base = raw_ptr.baseAddress else { return "" }
                return String(cString: base.assumingMemoryBound(to: CChar.self))
            }

            if name == "." || name == ".." { continue }

            let full_path = (directory as NSString).appendingPathComponent(name)
            guard let item = FileSystemProvider.shared.stat_item(at: full_path, name: name) else { continue }

            if matches(item: item, query: query, regex: regex) {
                results.append(item)
            }

            if item.is_directory && !item.is_symlink {
                search_recursive(directory: full_path, query: query, regex: regex, results: &results)
            }
        }
    }

    private func matches(item: FileItem, query: SearchQuery, regex: NSRegularExpression?) -> Bool {
        if let min = query.min_size, item.size < min && !item.is_directory { return false }
        if let max = query.max_size, item.size > max && !item.is_directory { return false }

        if !query.name_query.isEmpty {
            if let r = regex {
                let range = NSRange(location: 0, length: item.name.utf16.count)
                if r.firstMatch(in: item.name, range: range) == nil { return false }
            } else {
                if query.match_case {
                    if !item.name.contains(query.name_query) { return false }
                } else {
                    if !item.name.localizedCaseInsensitiveContains(query.name_query) { return false }
                }
            }
        }

        if let content = query.content_query, !content.isEmpty, !item.is_directory {
            if item.size > 10 * 1024 * 1024 { return false }
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: item.path)),
                  let text = String(data: data, encoding: .utf8) else {
                return false
            }
            if query.match_case {
                if !text.contains(content) { return false }
            } else {
                if !text.localizedCaseInsensitiveContains(content) { return false }
            }
        }

        return true
    }
}
