import UIKit

public struct InstalledAppItem: Sendable {
    public let name: String
    public let bundle_id: String
    public let version: String
    public let bundle_path: String
    public let data_container_path: String?
    public let icon_path: String?
    public let app_type: AppType

    public enum AppType: String, Sendable {
        case user = "User"
        case system = "System"
        case jailbreak = "Jailbreak"
    }
}

public final class AppManagerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    public var on_navigate_to_path: ((String) -> Void)?

    private let search_bar = UISearchBar()
    private let segmented_control = UISegmentedControl(items: ["All", "User", "System", "Jailbreak"])
    private let table_view = UITableView()
    private let activity_indicator = UIActivityIndicatorView(style: .medium)

    private var all_apps: [InstalledAppItem] = []
    private var filtered_apps: [InstalledAppItem] = []
    private let icon_cache = NSCache<NSString, UIImage>()

    public override func viewDidLoad() {
        super.viewDidLoad()
        setup_ui()
        load_applications()
    }

    private func setup_ui() {
        view.backgroundColor = MPTheme.background_dark
        title = "Installed Apps & Containers"

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(handle_close))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(load_applications))

        search_bar.translatesAutoresizingMaskIntoConstraints = false
        search_bar.barStyle = .black
        search_bar.placeholder = "Search apps by name or bundle ID..."
        search_bar.delegate = self
        view.addSubview(search_bar)

        segmented_control.translatesAutoresizingMaskIntoConstraints = false
        segmented_control.selectedSegmentIndex = 0
        segmented_control.selectedSegmentTintColor = MPTheme.primary_accent
        segmented_control.addTarget(self, action: #selector(handle_filter_change), for: .valueChanged)
        view.addSubview(segmented_control)

        table_view.translatesAutoresizingMaskIntoConstraints = false
        table_view.backgroundColor = .clear
        table_view.separatorColor = MPTheme.border_color
        table_view.delegate = self
        table_view.dataSource = self
        table_view.register(UITableViewCell.self, forCellReuseIdentifier: "AppCell")
        view.addSubview(table_view)

        activity_indicator.translatesAutoresizingMaskIntoConstraints = false
        activity_indicator.color = MPTheme.primary_accent
        view.addSubview(activity_indicator)

        NSLayoutConstraint.activate([
            search_bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            search_bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            search_bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            segmented_control.topAnchor.constraint(equalTo: search_bar.bottomAnchor, constant: 8),
            segmented_control.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmented_control.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            table_view.topAnchor.constraint(equalTo: segmented_control.bottomAnchor, constant: 8),
            table_view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table_view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table_view.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            activity_indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activity_indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func handle_close() {
        dismiss(animated: true)
    }

    @objc private func handle_filter_change() {
        filter_apps()
    }

    @objc private func load_applications() {
        activity_indicator.startAnimating()
        Task.detached(priority: .userInitiated) {
            let container_map = AppManagerViewController.scan_data_containers()
            var apps: [InstalledAppItem] = []

            let user_bundle_base = "/var/mobile/Containers/Bundle/Application"
            apps.append(contentsOf: AppManagerViewController.scan_directory_bundles(base_dir: user_bundle_base, type: .user, container_map: container_map))

            let jb_apps_base = RootlessPaths.jb("/Applications")
            apps.append(contentsOf: AppManagerViewController.scan_flat_bundles(base_dir: jb_apps_base, type: .jailbreak, container_map: container_map))

            let system_apps_base = "/Applications"
            apps.append(contentsOf: AppManagerViewController.scan_flat_bundles(base_dir: system_apps_base, type: .system, container_map: container_map))

            apps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            let final_apps = apps

            await MainActor.run {
                self.all_apps = final_apps
                self.activity_indicator.stopAnimating()
                self.filter_apps()
            }
        }
    }

    private nonisolated static func scan_data_containers() -> [String: String] {
        var map: [String: String] = [:]
        let data_base = "/var/mobile/Containers/Data/Application"
        guard let uuids = try? FileManager.default.contentsOfDirectory(atPath: data_base) else {
            return map
        }
        for uuid in uuids {
            let container_path = (data_base as NSString).appendingPathComponent(uuid)
            let meta_path = (container_path as NSString).appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
            if let dict = NSDictionary(contentsOfFile: meta_path) as? [String: Any],
               let id = dict["MCMMetadataIdentifier"] as? String {
                map[id] = container_path
            }
        }
        return map
    }

    private nonisolated static func scan_directory_bundles(base_dir: String, type: InstalledAppItem.AppType, container_map: [String: String]) -> [InstalledAppItem] {
        var results: [InstalledAppItem] = []
        guard let uuids = try? FileManager.default.contentsOfDirectory(atPath: base_dir) else { return results }
        for uuid in uuids {
            let uuid_dir = (base_dir as NSString).appendingPathComponent(uuid)
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: uuid_dir) else { continue }
            for item in contents where item.hasSuffix(".app") {
                let app_bundle_path = (uuid_dir as NSString).appendingPathComponent(item)
                if let app = parse_app_bundle(bundle_path: app_bundle_path, type: type, container_map: container_map) {
                    results.append(app)
                }
            }
        }
        return results
    }

    private nonisolated static func scan_flat_bundles(base_dir: String, type: InstalledAppItem.AppType, container_map: [String: String]) -> [InstalledAppItem] {
        var results: [InstalledAppItem] = []
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: base_dir) else { return results }
        for item in contents where item.hasSuffix(".app") {
            let app_bundle_path = (base_dir as NSString).appendingPathComponent(item)
            if let app = parse_app_bundle(bundle_path: app_bundle_path, type: type, container_map: container_map) {
                results.append(app)
            }
        }
        return results
    }

    private nonisolated static func parse_app_bundle(bundle_path: String, type: InstalledAppItem.AppType, container_map: [String: String]) -> InstalledAppItem? {
        let plist_path = (bundle_path as NSString).appendingPathComponent("Info.plist")
        guard let plist = NSDictionary(contentsOfFile: plist_path) as? [String: Any] else { return nil }

        let name = (plist["CFBundleDisplayName"] as? String) ?? (plist["CFBundleName"] as? String) ?? (bundle_path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        let bundle_id = (plist["CFBundleIdentifier"] as? String) ?? "unknown.bundle.id"
        let version = (plist["CFBundleShortVersionString"] as? String) ?? (plist["CFBundleVersion"] as? String) ?? "1.0"
        let data_dir = container_map[bundle_id]

        var icon_file_path: String? = nil
        var candidate_names: [String] = []

        if let icons_dict = plist["CFBundleIcons"] as? [String: Any],
           let primary = icons_dict["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String] {
            candidate_names.append(contentsOf: files)
        }
        if let icons_ipad = plist["CFBundleIcons~ipad"] as? [String: Any],
           let primary = icons_ipad["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String] {
            candidate_names.append(contentsOf: files)
        }
        if let files = plist["CFBundleIconFiles"] as? [String] {
            candidate_names.append(contentsOf: files)
        }
        if let single = plist["CFBundleIconFile"] as? String {
            candidate_names.append(single)
        }

        for c_name in candidate_names.reversed() {
            let variants = [
                c_name + "@3x.png",
                c_name + "@2x.png",
                c_name + "@2x~ipad.png",
                c_name + "~ipad.png",
                c_name + ".png",
                c_name
            ]
            for v in variants {
                let full = (bundle_path as NSString).appendingPathComponent(v)
                if FileManager.default.fileExists(atPath: full) {
                    icon_file_path = full
                    break
                }
            }
            if icon_file_path != nil { break }
        }

        if icon_file_path == nil {
            if let bundle_contents = try? FileManager.default.contentsOfDirectory(atPath: bundle_path) {
                let candidates = bundle_contents.filter {
                    let lower = $0.lowercased()
                    return lower.hasSuffix(".png") && (lower.contains("icon") || lower.contains("appicon"))
                }.sorted { $0.count > $1.count }
                if let first_icon = candidates.first {
                    icon_file_path = (bundle_path as NSString).appendingPathComponent(first_icon)
                }
            }
        }

        return InstalledAppItem(
            name: name,
            bundle_id: bundle_id,
            version: version,
            bundle_path: bundle_path,
            data_container_path: data_dir,
            icon_path: icon_file_path,
            app_type: type
        )
    }

    private func resolve_app_icon(for app: InstalledAppItem) -> UIImage? {
        let cache_key = app.bundle_id as NSString
        if let cached = icon_cache.object(forKey: cache_key) {
            return cached
        }

        if let path = app.icon_path, let raw_img = UIImage(contentsOfFile: path) {
            let scaled = scale_icon(raw_img)
            icon_cache.setObject(scaled, forKey: cache_key)
            return scaled
        }

        let sel = NSSelectorFromString("_applicationIconImageForBundleIdentifier:format:scale:")
        if let method = class_getClassMethod(UIImage.self, sel) {
            typealias Func = @convention(c) (AnyClass, Selector, NSString, Int32, CGFloat) -> AnyObject?
            let imp = method_getImplementation(method)
            let fn = unsafeBitCast(imp, to: Func.self)
            if let obj = fn(UIImage.self, sel, app.bundle_id as NSString, 2, 2.0) as? UIImage {
                let scaled = scale_icon(obj)
                icon_cache.setObject(scaled, forKey: cache_key)
                return scaled
            }
        }

        return nil
    }

    private func scale_icon(_ image: UIImage, size: CGSize = CGSize(width: 38, height: 38)) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        let rect = CGRect(origin: .zero, size: size)
        UIBezierPath(roundedRect: rect, cornerRadius: 8).addClip()
        image.draw(in: rect)
        let scaled = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return scaled
    }

    private func filter_apps() {
        let query = search_bar.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let seg_idx = segmented_control.selectedSegmentIndex

        filtered_apps = all_apps.filter { app in
            let matches_search = query.isEmpty || app.name.lowercased().contains(query) || app.bundle_id.lowercased().contains(query)
            if !matches_search { return false }
            switch seg_idx {
            case 1: return app.app_type == .user
            case 2: return app.app_type == .system
            case 3: return app.app_type == .jailbreak
            default: return true
            }
        }
        table_view.reloadData()
    }

    public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filter_apps()
    }

    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filtered_apps.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "AppCell")
        cell.backgroundColor = .clear
        cell.textLabel?.textColor = MPTheme.text_primary
        cell.textLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        cell.detailTextLabel?.textColor = MPTheme.text_secondary
        cell.detailTextLabel?.font = .monospacedSystemFont(ofSize: 12, weight: .regular)

        let app = filtered_apps[indexPath.row]
        cell.textLabel?.text = "\(app.name) (\(app.version))"
        cell.detailTextLabel?.text = "[\(app.app_type.rawValue)] \(app.bundle_id)"

        if let icon = resolve_app_icon(for: app) {
            cell.imageView?.image = icon
            cell.imageView?.layer.cornerRadius = 8
            cell.imageView?.clipsToBounds = true
        } else {
            let icon_img: UIImage?
            switch app.app_type {
            case .jailbreak:
                icon_img = UIImage(systemName: "terminal")
            case .system:
                icon_img = UIImage(systemName: "applelogo")
            case .user:
                icon_img = UIImage(systemName: "app.gift")
            }
            cell.imageView?.image = icon_img
            cell.imageView?.tintColor = MPTheme.primary_accent
            cell.imageView?.layer.cornerRadius = 0
            cell.imageView?.clipsToBounds = false
        }
        return cell
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let app = filtered_apps[indexPath.row]
        show_app_options(app)
    }

    private func show_app_options(_ app: InstalledAppItem) {
        let alert = UIAlertController(title: app.name, message: "Bundle ID: \(app.bundle_id)\nVersion: \(app.version)", preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Browse App Bundle Folder", style: .default, handler: { [weak self] _ in
            self?.dismiss(animated: true) {
                self?.on_navigate_to_path?(app.bundle_path)
            }
        }))

        if let data_dir = app.data_container_path {
            alert.addAction(UIAlertAction(title: "Browse Data Container Folder", style: .default, handler: { [weak self] _ in
                self?.dismiss(animated: true) {
                    self?.on_navigate_to_path?(data_dir)
                }
            }))
        }

        alert.addAction(UIAlertAction(title: "Copy Bundle ID", style: .default, handler: { _ in
            UIPasteboard.general.string = app.bundle_id
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = table_view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        present(alert, animated: true)
    }
}
