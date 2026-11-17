import UIKit

public final class RemoteFilesViewController: UIViewController {
    private let connection: NetworkStorageItem
    private let password: String?
    private var current_path: String
    private var files: [RemoteFileInfo] = []

    private let path_label = UILabel()
    private let table_view = UITableView()
    private let activity_indicator = UIActivityIndicatorView(style: .medium)

    public var on_file_downloaded: ((String) -> Void)?

    public init(connection: NetworkStorageItem, password: String?) {
        self.connection = connection
        self.password = password
        self.current_path = connection.path.isEmpty ? "/" : connection.path
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = connection.name
        view.backgroundColor = MPTheme.surface_dark

        setup_navigation()
        setup_ui()
        load_directory()
    }

    private func setup_navigation() {
        let add_btn = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(show_actions))
        let refresh_btn = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(load_directory))
        navigationItem.rightBarButtonItems = [add_btn, refresh_btn]
    }

    private func setup_ui() {
        let top_bar = UIView()
        top_bar.backgroundColor = MPTheme.background_dark
        top_bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(top_bar)

        path_label.textColor = MPTheme.text_secondary
        path_label.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        path_label.translatesAutoresizingMaskIntoConstraints = false
        top_bar.addSubview(path_label)

        table_view.backgroundColor = .clear
        table_view.separatorColor = MPTheme.border_color
        table_view.translatesAutoresizingMaskIntoConstraints = false
        table_view.delegate = self
        table_view.dataSource = self
        table_view.register(UITableViewCell.self, forCellReuseIdentifier: "RemoteCell")
        view.addSubview(table_view)

        activity_indicator.color = MPTheme.primary_accent
        activity_indicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activity_indicator)

        NSLayoutConstraint.activate([
            top_bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            top_bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            top_bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            top_bar.heightAnchor.constraint(equalToConstant: 32),

            path_label.leadingAnchor.constraint(equalTo: top_bar.leadingAnchor, constant: 12),
            path_label.trailingAnchor.constraint(equalTo: top_bar.trailingAnchor, constant: -12),
            path_label.centerYAnchor.constraint(equalTo: top_bar.centerYAnchor),

            table_view.topAnchor.constraint(equalTo: top_bar.bottomAnchor),
            table_view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table_view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table_view.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            activity_indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activity_indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func load_directory() {
        path_label.text = "\(connection.proto.rawValue)://\(connection.host)\(current_path)"
        activity_indicator.startAnimating()

        Task {
            do {
                let items = try await NetworkStorageClient.shared.list_directory(item: connection, path: current_path, password: password)
                let sorted = items.sorted {
                    if $0.is_directory != $1.is_directory {
                        return $0.is_directory && !$1.is_directory
                    }
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
                await MainActor.run {
                    self.activity_indicator.stopAnimating()
                    self.files = sorted
                    self.table_view.reloadData()
                }
            } catch {
                await MainActor.run {
                    self.activity_indicator.stopAnimating()
                    let alert = UIAlertController(title: "Listing Failed", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    @objc private func show_actions() {
        let sheet = UIAlertController(title: "Remote Actions", message: "Path: \(current_path)", preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "New Remote Folder", style: .default, handler: { [weak self] _ in
            self?.prompt_create_folder()
        }))
        sheet.addAction(UIAlertAction(title: "Upload Local File...", style: .default, handler: { [weak self] _ in
            self?.prompt_upload_file()
        }))
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.barButtonItem = navigationItem.rightBarButtonItems?.first
        }
        present(sheet, animated: true)
    }

    private func prompt_create_folder() {
        let alert = UIAlertController(title: "New Folder", message: "Enter folder name:", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Folder name" }
        alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { [weak self] _ in
            guard let self = self, let name = alert.textFields?.first?.text, !name.isEmpty else { return }
            let new_path = (self.current_path as NSString).appendingPathComponent(name)
            Task {
                do {
                    try await NetworkStorageClient.shared.create_directory(item: self.connection, path: new_path, password: self.password)
                    await MainActor.run {
                        self.load_directory()
                    }
                } catch {
                    await MainActor.run {
                        let err_alert = UIAlertController(title: "Create Failed", message: error.localizedDescription, preferredStyle: .alert)
                        err_alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(err_alert, animated: true)
                    }
                }
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func prompt_upload_file() {
        let alert = UIAlertController(title: "Upload File", message: "Enter local file path to upload to \(current_path):", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "/var/mobile/Downloads/sample.txt" }
        alert.addAction(UIAlertAction(title: "Upload", style: .default, handler: { [weak self] _ in
            guard let self = self, let local_path = alert.textFields?.first?.text, !local_path.isEmpty else { return }
            let name = (local_path as NSString).lastPathComponent
            let remote_dest = (self.current_path as NSString).appendingPathComponent(name)

            self.activity_indicator.startAnimating()
            Task {
                do {
                    try await NetworkStorageClient.shared.upload_file(item: self.connection, local_source: local_path, remote_path: remote_dest, password: self.password)
                    await MainActor.run {
                        self.activity_indicator.stopAnimating()
                        self.load_directory()
                    }
                } catch {
                    await MainActor.run {
                        self.activity_indicator.stopAnimating()
                        let err_alert = UIAlertController(title: "Upload Failed", message: error.localizedDescription, preferredStyle: .alert)
                        err_alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(err_alert, animated: true)
                    }
                }
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func handle_item_selected(_ item: RemoteFileInfo) {
        if item.is_directory {
            if item.name == ".." {
                current_path = (current_path as NSString).deletingLastPathComponent
                if current_path.isEmpty { current_path = "/" }
            } else {
                current_path = (current_path as NSString).appendingPathComponent(item.name)
            }
            load_directory()
        } else {
            let sheet = UIAlertController(title: item.name, message: "Size: \(FileItem.format_bytes(item.size))", preferredStyle: .actionSheet)
            sheet.addAction(UIAlertAction(title: "Download to /var/mobile/Media", style: .default, handler: { [weak self] _ in
                self?.download_item(item, destination_dir: "/var/mobile/Media")
            }))
            sheet.addAction(UIAlertAction(title: "Download & Open Text Editor", style: .default, handler: { [weak self] _ in
                self?.download_and_edit(item)
            }))
            sheet.addAction(UIAlertAction(title: "Delete from Server", style: .destructive, handler: { [weak self] _ in
                self?.delete_remote_item(item)
            }))
            sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(sheet, animated: true)
        }
    }

    private func download_item(_ item: RemoteFileInfo, destination_dir: String) {
        let dest = (destination_dir as NSString).appendingPathComponent(item.name)
        let remote_src = (current_path as NSString).appendingPathComponent(item.name)
        activity_indicator.startAnimating()

        Task {
            do {
                try await NetworkStorageClient.shared.download_file(item: connection, remote_path: remote_src, local_destination: dest, password: password)
                await MainActor.run {
                    self.activity_indicator.stopAnimating()
                    let alert = UIAlertController(title: "Downloaded", message: "Saved to \(dest)", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                    self.on_file_downloaded?(dest)
                }
            } catch {
                await MainActor.run {
                    self.activity_indicator.stopAnimating()
                    let alert = UIAlertController(title: "Download Failed", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    private func download_and_edit(_ item: RemoteFileInfo) {
        let temp_dir = NSTemporaryDirectory()
        let dest = (temp_dir as NSString).appendingPathComponent(item.name)
        let remote_src = (current_path as NSString).appendingPathComponent(item.name)
        activity_indicator.startAnimating()

        Task {
            do {
                try await NetworkStorageClient.shared.download_file(item: connection, remote_path: remote_src, local_destination: dest, password: password)
                await MainActor.run {
                    self.activity_indicator.stopAnimating()
                    let editor = TextEditorViewController(file_path: dest)
                    self.navigationController?.pushViewController(editor, animated: true)
                }
            } catch {
                await MainActor.run {
                    self.activity_indicator.stopAnimating()
                    let alert = UIAlertController(title: "Download Failed", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    private func delete_remote_item(_ item: RemoteFileInfo) {
        let target = (current_path as NSString).appendingPathComponent(item.name)
        activity_indicator.startAnimating()

        Task {
            do {
                try await NetworkStorageClient.shared.delete_file(item: connection, path: target, password: password)
                await MainActor.run {
                    self.activity_indicator.stopAnimating()
                    self.load_directory()
                }
            } catch {
                await MainActor.run {
                    self.activity_indicator.stopAnimating()
                    let alert = UIAlertController(title: "Delete Failed", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
}

extension RemoteFilesViewController: UITableViewDataSource, UITableViewDelegate {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let has_parent = current_path != "/" && !current_path.isEmpty
        return files.count + (has_parent ? 1 : 0)
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RemoteCell", for: indexPath)
        cell.backgroundColor = .clear

        let has_parent = current_path != "/" && !current_path.isEmpty
        if has_parent && indexPath.row == 0 {
            cell.textLabel?.textColor = MPTheme.secondary_accent
            cell.textLabel?.text = "📁 .."
            cell.detailTextLabel?.text = "Parent Directory"
            cell.imageView?.image = UIImage(systemName: "arrow.up.folder")?.withTintColor(MPTheme.secondary_accent, renderingMode: .alwaysOriginal)
            return cell
        }

        let file_index = has_parent ? (indexPath.row - 1) : indexPath.row
        let item = files[file_index]

        cell.textLabel?.textColor = MPTheme.text_primary
        cell.textLabel?.text = item.name
        cell.detailTextLabel?.textColor = MPTheme.text_secondary

        if item.is_directory {
            cell.imageView?.image = UIImage(systemName: "folder.fill")?.withTintColor(MPTheme.folder_amber, renderingMode: .alwaysOriginal)
            cell.detailTextLabel?.text = "Directory"
        } else {
            cell.imageView?.image = UIImage(systemName: "doc.fill")?.withTintColor(MPTheme.text_secondary, renderingMode: .alwaysOriginal)
            cell.detailTextLabel?.text = FileItem.format_bytes(item.size)
        }

        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let has_parent = current_path != "/" && !current_path.isEmpty
        if has_parent && indexPath.row == 0 {
            current_path = (current_path as NSString).deletingLastPathComponent
            if current_path.isEmpty { current_path = "/" }
            load_directory()
            return
        }

        let file_index = has_parent ? (indexPath.row - 1) : indexPath.row
        let item = files[file_index]
        handle_item_selected(item)
    }
}
