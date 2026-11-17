import Foundation

public struct BookmarkItem: Codable, Identifiable, Hashable, Sendable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let group: String

    public init(name: String, path: String, group: String = "Default") {
        self.name = name
        self.path = path
        self.group = group
    }
}

public final class BookmarkStore: @unchecked Sendable {
    public static let shared = BookmarkStore()

    private let bookmarks_key = "mp_bookmarks_v1"
    private let history_key_pane1 = "mp_history_pane1_v1"
    private let history_key_pane2 = "mp_history_pane2_v1"
    private let defaults = UserDefaults.standard
    private let lock = NSLock()

    private init() {
        if bookmarks.isEmpty {
            add_default_bookmarks()
        }
    }

    public var bookmarks: [BookmarkItem] {
        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: bookmarks_key),
              let list = try? JSONDecoder().decode([BookmarkItem].self, from: data) else {
            return []
        }
        return list
    }

    public func add_bookmark(name: String, path: String, group: String = "Default") {
        lock.lock()
        defer { lock.unlock() }
        var current = bookmarks_unlocked
        if !current.contains(where: { $0.path == path }) {
            current.append(BookmarkItem(name: name, path: path, group: group))
            save_bookmarks_unlocked(current)
        }
    }

    public func remove_bookmark(path: String) {
        lock.lock()
        defer { lock.unlock() }
        var current = bookmarks_unlocked
        current.removeAll { $0.path == path }
        save_bookmarks_unlocked(current)
    }

    public func add_history(path: String, pane: Int) {
        lock.lock()
        defer { lock.unlock() }
        let key = pane == 1 ? history_key_pane1 : history_key_pane2
        var list = defaults.stringArray(forKey: key) ?? []
        list.removeAll { $0 == path }
        list.insert(path, at: 0)
        if list.count > 50 {
            list = Array(list.prefix(50))
        }
        defaults.set(list, forKey: key)
    }

    public func get_history(pane: Int) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        let key = pane == 1 ? history_key_pane1 : history_key_pane2
        return defaults.stringArray(forKey: key) ?? []
    }

    private var bookmarks_unlocked: [BookmarkItem] {
        guard let data = defaults.data(forKey: bookmarks_key),
              let list = try? JSONDecoder().decode([BookmarkItem].self, from: data) else {
            return []
        }
        return list
    }

    private func save_bookmarks_unlocked(_ list: [BookmarkItem]) {
        if let data = try? JSONEncoder().encode(list) {
            defaults.set(data, forKey: bookmarks_key)
        }
    }

    private func add_default_bookmarks() {
        var initial = [
            BookmarkItem(name: "Internal Storage", path: "/var/mobile", group: "System"),
            BookmarkItem(name: "Media", path: "/var/mobile/Media", group: "Storage"),
            BookmarkItem(name: "Rootless JB", path: RootlessPaths.resolved_jailbreak_path, group: "Jailbreak"),
            BookmarkItem(name: "Applications", path: RootlessPaths.applications_path, group: "Applications")
        ]
        if FileManager.default.fileExists(atPath: "/var/mobile/Documents") {
            initial.append(BookmarkItem(name: "Documents", path: "/var/mobile/Documents", group: "Storage"))
        }
        save_bookmarks_unlocked(initial)
    }
}
