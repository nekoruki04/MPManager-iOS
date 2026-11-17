import UIKit

public struct StorageFileInfo: Sendable {
    public let path: String
    public let name: String
    public let size: UInt64
    public let formatted_size: String
}

public final class StorageManagerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    public var on_locate_file: ((String) -> Void)?

    private let total_label = UILabel()
    private let used_label = UILabel()
    private let free_label = UILabel()
    private let progress_view = UIProgressView(progressViewStyle: .default)

    private let scan_button = UIButton(type: .system)
    private let activity_indicator = UIActivityIndicatorView(style: .medium)
    private let table_view = UITableView()

    private var largest_files: [StorageFileInfo] = []

    public override func viewDidLoad() {
        super.viewDidLoad()
        setup_ui()
        load_storage_stats()
    }

    private func setup_ui() {
        view.backgroundColor = MPTheme.background_dark
        title = "Storage Manager"

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(handle_close))

        let header_card = UIView()
        header_card.translatesAutoresizingMaskIntoConstraints = false
        header_card.backgroundColor = MPTheme.surface_dark
        header_card.layer.cornerRadius = 8
        view.addSubview(header_card)

        total_label.translatesAutoresizingMaskIntoConstraints = false
        total_label.font = .systemFont(ofSize: 14, weight: .medium)
        total_label.textColor = MPTheme.text_secondary
        total_label.text = "Total Space: Calculating..."
        header_card.addSubview(total_label)

        progress_view.translatesAutoresizingMaskIntoConstraints = false
        progress_view.progressTintColor = MPTheme.primary_accent
        progress_view.trackTintColor = MPTheme.border_color
        progress_view.layer.cornerRadius = 4
        progress_view.clipsToBounds = true
        header_card.addSubview(progress_view)

        used_label.translatesAutoresizingMaskIntoConstraints = false
        used_label.font = .systemFont(ofSize: 12)
        used_label.textColor = MPTheme.text_primary
        header_card.addSubview(used_label)

        free_label.translatesAutoresizingMaskIntoConstraints = false
        free_label.font = .systemFont(ofSize: 12)
        free_label.textColor = MPTheme.text_secondary
        header_card.addSubview(free_label)

        scan_button.translatesAutoresizingMaskIntoConstraints = false
        scan_button.setTitle("Scan Largest Files", for: .normal)
        scan_button.setTitleColor(.white, for: .normal)
        scan_button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        scan_button.backgroundColor = MPTheme.primary_accent
        scan_button.layer.cornerRadius = 6
        scan_button.addTarget(self, action: #selector(start_scan_largest_files), for: .touchUpInside)
        view.addSubview(scan_button)

        activity_indicator.translatesAutoresizingMaskIntoConstraints = false
        activity_indicator.color = MPTheme.primary_accent
        view.addSubview(activity_indicator)

        let section_header = UILabel()
        section_header.translatesAutoresizingMaskIntoConstraints = false
        section_header.text = "Largest Files on Disk"
        section_header.font = .systemFont(ofSize: 14, weight: .bold)
        section_header.textColor = MPTheme.text_primary
        view.addSubview(section_header)

        table_view.translatesAutoresizingMaskIntoConstraints = false
        table_view.backgroundColor = .clear
        table_view.separatorColor = MPTheme.border_color
        table_view.delegate = self
        table_view.dataSource = self
        table_view.register(UITableViewCell.self, forCellReuseIdentifier: "FileCell")
        view.addSubview(table_view)

        NSLayoutConstraint.activate([
            header_card.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            header_card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            header_card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            total_label.topAnchor.constraint(equalTo: header_card.topAnchor, constant: 14),
            total_label.leadingAnchor.constraint(equalTo: header_card.leadingAnchor, constant: 14),
            total_label.trailingAnchor.constraint(equalTo: header_card.trailingAnchor, constant: -14),

            progress_view.topAnchor.constraint(equalTo: total_label.bottomAnchor, constant: 10),
            progress_view.leadingAnchor.constraint(equalTo: total_label.leadingAnchor),
            progress_view.trailingAnchor.constraint(equalTo: total_label.trailingAnchor),
            progress_view.heightAnchor.constraint(equalToConstant: 8),

            used_label.topAnchor.constraint(equalTo: progress_view.bottomAnchor, constant: 8),
            used_label.leadingAnchor.constraint(equalTo: total_label.leadingAnchor),
            used_label.bottomAnchor.constraint(equalTo: header_card.bottomAnchor, constant: -14),

            free_label.topAnchor.constraint(equalTo: used_label.topAnchor),
            free_label.trailingAnchor.constraint(equalTo: total_label.trailingAnchor),

            scan_button.topAnchor.constraint(equalTo: header_card.bottomAnchor, constant: 14),
            scan_button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scan_button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scan_button.heightAnchor.constraint(equalToConstant: 40),

            activity_indicator.centerYAnchor.constraint(equalTo: scan_button.centerYAnchor),
            activity_indicator.trailingAnchor.constraint(equalTo: scan_button.trailingAnchor, constant: -16),

            section_header.topAnchor.constraint(equalTo: scan_button.bottomAnchor, constant: 16),
            section_header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            table_view.topAnchor.constraint(equalTo: section_header.bottomAnchor, constant: 8),
            table_view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table_view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table_view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func load_storage_stats() {
        let path = "/var/mobile"
        var stat = statvfs()
        if statvfs(path, &stat) == 0 {
            let total = UInt64(stat.f_blocks) * UInt64(stat.f_frsize)
            let free = UInt64(stat.f_bavail) * UInt64(stat.f_frsize)
            let used = total > free ? (total - free) : 0

            let total_str = ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
            let free_str = ByteCountFormatter.string(fromByteCount: Int64(free), countStyle: .file)
            let used_str = ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .file)

            total_label.text = "Storage Capacity (\(path))"
            used_label.text = "Used: \(used_str)"
            free_label.text = "Free: \(free_str) of \(total_str)"

            if total > 0 {
                progress_view.progress = Float(Double(used) / Double(total))
            }
        }
    }

    @objc private func handle_close() {
        dismiss(animated: true)
    }

    @objc private func start_scan_largest_files() {
        activity_indicator.startAnimating()
        scan_button.isEnabled = false

        Task.detached(priority: .userInitiated) {
            let scan_roots = [
                "/var/mobile/Media",
                "/var/mobile/Downloads",
                "/var/mobile/Documents",
                RootlessPaths.jb("/var/cache"),
                RootlessPaths.jb("/tmp")
            ]

            var found_files: [StorageFileInfo] = []
            for root in scan_roots {
                StorageManagerViewController.scan_directory_recursive(path: root, results: &found_files, max_depth: 4)
            }

            found_files.sort { $0.size > $1.size }
            let top50 = Array(found_files.prefix(50))

            await MainActor.run {
                self.largest_files = top50
                self.activity_indicator.stopAnimating()
                self.scan_button.isEnabled = true
                self.table_view.reloadData()
            }
        }
    }

    private nonisolated static func scan_directory_recursive(path: String, results: inout [StorageFileInfo], max_depth: Int) {
        guard max_depth > 0 else { return }
        guard let dir = opendir(path) else { return }
        defer { closedir(dir) }

        while let entry = readdir(dir) {
            let name = withUnsafeBytes(of: entry.pointee.d_name) { raw in
                raw.bindMemory(to: CChar.self).baseAddress.map { String(cString: $0) } ?? ""
            }
            if name == "." || name == ".." { continue }

            let full_path = (path as NSString).appendingPathComponent(name)
            var st = stat()
            if lstat(full_path, &st) == 0 {
                let is_dir = (st.st_mode & S_IFMT) == S_IFDIR
                if is_dir {
                    scan_directory_recursive(path: full_path, results: &results, max_depth: max_depth - 1)
                } else if (st.st_mode & S_IFMT) == S_IFREG {
                    let sz = UInt64(st.st_size)
                    if sz > 5 * 1024 * 1024 {
                        let fmt = ByteCountFormatter.string(fromByteCount: Int64(sz), countStyle: .file)
                        results.append(StorageFileInfo(path: full_path, name: name, size: sz, formatted_size: fmt))
                    }
                }
            }
        }
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return largest_files.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "FileCell")
        cell.backgroundColor = .clear
        cell.textLabel?.textColor = MPTheme.text_primary
        cell.textLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        cell.detailTextLabel?.textColor = MPTheme.text_secondary
        cell.detailTextLabel?.font = .monospacedSystemFont(ofSize: 11, weight: .regular)

        let file = largest_files[indexPath.row]
        cell.textLabel?.text = "\(file.name)  (\(file.formatted_size))"
        cell.detailTextLabel?.text = file.path
        cell.imageView?.image = UIImage(systemName: "doc.fill")
        cell.imageView?.tintColor = MPTheme.folder_amber
        return cell
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let file = largest_files[indexPath.row]
        let alert = UIAlertController(title: file.name, message: "\(file.formatted_size)\n\(file.path)", preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Locate in Pane", style: .default, handler: { [weak self] _ in
            let dir = (file.path as NSString).deletingLastPathComponent
            self?.dismiss(animated: true) {
                self?.on_locate_file?(dir)
            }
        }))

        alert.addAction(UIAlertAction(title: "Delete File", style: .destructive, handler: { [weak self] _ in
            self?.confirm_delete(file: file, index: indexPath.row)
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = tableView.rectForRow(at: indexPath)
        }
        present(alert, animated: true)
    }

    private func confirm_delete(file: StorageFileInfo, index: Int) {
        let alert = UIAlertController(title: "Delete", message: "Permanently delete \(file.name)?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            do {
                try FileManager.default.removeItem(atPath: file.path)
                self?.largest_files.remove(at: index)
                self?.table_view.reloadData()
                self?.load_storage_stats()
            } catch {
                let err = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                err.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(err, animated: true)
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}
