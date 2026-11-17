import UIKit

public final class DualPaneViewController: UIViewController {
    private var pane1_vc: MainFilesViewController!
    private var pane2_vc: MainFilesViewController!
    private var active_pane_id: Int = 1

    private let top_bar = UIView()
    private let hamburger_btn = UIButton(type: .system)
    private let path_label = UILabel()
    private let count_label = UILabel()
    private let more_btn = UIButton(type: .system)

    private let panes_container = UIStackView()
    private let bottom_bar = UIView()
    private let back_btn = UIButton(type: .system)
    private let forward_btn = UIButton(type: .system)
    private let add_btn = UIButton(type: .system)
    private let sync_btn = UIButton(type: .system)
    private let up_btn = UIButton(type: .system)

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = MPTheme.background_dark
        navigationController?.setNavigationBarHidden(true, animated: false)

        setup_panes()
        setup_ui()
        update_active_pane(1)
    }

    private func setup_panes() {
        let default_path1 = RootlessPaths.default_mobile_documents
        let default_path2 = RootlessPaths.resolved_jailbreak_path

        pane1_vc = MainFilesViewController(pane_id: 1, initial_path: default_path1)
        pane1_vc.delegate = self

        pane2_vc = MainFilesViewController(pane_id: 2, initial_path: default_path2)
        pane2_vc.delegate = self
    }

    private func setup_ui() {
        setup_top_bar()
        setup_bottom_bar()
        setup_panes_layout()
    }

    private func setup_top_bar() {
        top_bar.translatesAutoresizingMaskIntoConstraints = false
        top_bar.backgroundColor = MPTheme.surface_dark
        view.addSubview(top_bar)

        hamburger_btn.translatesAutoresizingMaskIntoConstraints = false
        hamburger_btn.setImage(UIImage(systemName: "line.3.horizontal")?.withTintColor(MPTheme.text_primary, renderingMode: .alwaysOriginal), for: .normal)
        hamburger_btn.addTarget(self, action: #selector(open_sidebar), for: .touchUpInside)
        top_bar.addSubview(hamburger_btn)

        let title_stack = UIStackView()
        title_stack.translatesAutoresizingMaskIntoConstraints = false
        title_stack.axis = .vertical
        title_stack.spacing = 2

        path_label.textColor = MPTheme.text_primary
        path_label.font = UIFont.boldSystemFont(ofSize: 15)
        path_label.lineBreakMode = .byTruncatingMiddle

        count_label.textColor = MPTheme.text_secondary
        count_label.font = UIFont.systemFont(ofSize: 11)

        title_stack.addArrangedSubview(path_label)
        title_stack.addArrangedSubview(count_label)
        top_bar.addSubview(title_stack)

        more_btn.translatesAutoresizingMaskIntoConstraints = false
        more_btn.setImage(UIImage(systemName: "ellipsis")?.withTintColor(MPTheme.text_primary, renderingMode: .alwaysOriginal), for: .normal)
        more_btn.addTarget(self, action: #selector(open_more_menu), for: .touchUpInside)
        top_bar.addSubview(more_btn)

        NSLayoutConstraint.activate([
            top_bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            top_bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            top_bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            top_bar.heightAnchor.constraint(equalToConstant: 52),

            hamburger_btn.leadingAnchor.constraint(equalTo: top_bar.leadingAnchor, constant: 12),
            hamburger_btn.centerYAnchor.constraint(equalTo: top_bar.centerYAnchor),
            hamburger_btn.widthAnchor.constraint(equalToConstant: 32),
            hamburger_btn.heightAnchor.constraint(equalToConstant: 32),

            title_stack.leadingAnchor.constraint(equalTo: hamburger_btn.trailingAnchor, constant: 12),
            title_stack.trailingAnchor.constraint(equalTo: more_btn.leadingAnchor, constant: -12),
            title_stack.centerYAnchor.constraint(equalTo: top_bar.centerYAnchor),

            more_btn.trailingAnchor.constraint(equalTo: top_bar.trailingAnchor, constant: -12),
            more_btn.centerYAnchor.constraint(equalTo: top_bar.centerYAnchor),
            more_btn.widthAnchor.constraint(equalToConstant: 32),
            more_btn.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    private func setup_bottom_bar() {
        bottom_bar.translatesAutoresizingMaskIntoConstraints = false
        bottom_bar.backgroundColor = MPTheme.surface_dark
        view.addSubview(bottom_bar)

        let bar_stack = UIStackView()
        bar_stack.translatesAutoresizingMaskIntoConstraints = false
        bar_stack.axis = .horizontal
        bar_stack.distribution = .fillEqually
        bar_stack.alignment = .center

        configure_bar_btn(back_btn, icon: "chevron.left", action: #selector(handle_back))
        configure_bar_btn(forward_btn, icon: "chevron.right", action: #selector(handle_forward))
        configure_bar_btn(add_btn, icon: "plus", action: #selector(handle_add))
        configure_bar_btn(sync_btn, icon: "arrow.left.arrow.right", action: #selector(handle_sync))
        configure_bar_btn(up_btn, icon: "arrow.up", action: #selector(handle_up))

        bar_stack.addArrangedSubview(back_btn)
        bar_stack.addArrangedSubview(forward_btn)
        bar_stack.addArrangedSubview(add_btn)
        bar_stack.addArrangedSubview(sync_btn)
        bar_stack.addArrangedSubview(up_btn)

        bottom_bar.addSubview(bar_stack)

        let swipe_up = UISwipeGestureRecognizer(target: self, action: #selector(open_bookmarks_drawer))
        swipe_up.direction = .up
        bottom_bar.addGestureRecognizer(swipe_up)

        NSLayoutConstraint.activate([
            bottom_bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottom_bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottom_bar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottom_bar.heightAnchor.constraint(equalToConstant: 50),

            bar_stack.topAnchor.constraint(equalTo: bottom_bar.topAnchor),
            bar_stack.leadingAnchor.constraint(equalTo: bottom_bar.leadingAnchor),
            bar_stack.trailingAnchor.constraint(equalTo: bottom_bar.trailingAnchor),
            bar_stack.bottomAnchor.constraint(equalTo: bottom_bar.bottomAnchor)
        ])
    }

    private func configure_bar_btn(_ btn: UIButton, icon: String, action: Selector) {
        btn.setImage(UIImage(systemName: icon)?.withTintColor(MPTheme.text_primary, renderingMode: .alwaysOriginal), for: .normal)
        btn.addTarget(self, action: action, for: .touchUpInside)
    }

    private func setup_panes_layout() {
        panes_container.translatesAutoresizingMaskIntoConstraints = false
        panes_container.axis = .horizontal
        panes_container.distribution = .fillEqually
        panes_container.spacing = 1
        panes_container.backgroundColor = MPTheme.border_color
        view.addSubview(panes_container)

        addChild(pane1_vc)
        panes_container.addArrangedSubview(pane1_vc.view)
        pane1_vc.didMove(toParent: self)

        addChild(pane2_vc)
        panes_container.addArrangedSubview(pane2_vc.view)
        pane2_vc.didMove(toParent: self)

        NSLayoutConstraint.activate([
            panes_container.topAnchor.constraint(equalTo: top_bar.bottomAnchor),
            panes_container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panes_container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panes_container.bottomAnchor.constraint(equalTo: bottom_bar.topAnchor)
        ])
    }

    private func update_active_pane(_ id: Int) {
        active_pane_id = id
        pane1_vc.is_active = (id == 1)
        pane2_vc.is_active = (id == 2)

        let active_vc = (id == 1) ? pane1_vc! : pane2_vc!
        path_label.text = active_vc.current_path
    }

    private var active_pane: MainFilesViewController {
        active_pane_id == 1 ? pane1_vc : pane2_vc
    }

    private var inactive_pane: MainFilesViewController {
        active_pane_id == 1 ? pane2_vc : pane1_vc
    }

    @objc private func handle_back() {
        active_pane.navigate_back()
    }

    @objc private func handle_forward() {
        active_pane.navigate_forward()
    }

    @objc private func handle_up() {
        active_pane.navigate_up()
    }

    @objc private func handle_sync() {
        let source_path = active_pane.current_path
        inactive_pane.navigate_to(path: source_path)
    }

    @objc private func handle_add() {
        let alert = UIAlertController(title: "New Item", message: "Choose item type to create:", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "New Folder", style: .default, handler: { [weak self] _ in
            self?.prompt_create_item(is_directory: true)
        }))
        alert.addAction(UIAlertAction(title: "New File", style: .default, handler: { [weak self] _ in
            self?.prompt_create_item(is_directory: false)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present_adaptive_sheet(alert)
    }

    private func prompt_create_item(is_directory: Bool) {
        let title = is_directory ? "New Folder" : "New File"
        let alert = UIAlertController(title: title, message: "Enter name:", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = is_directory ? "FolderName" : "filename.txt" }
        alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { [weak self] _ in
            guard let self = self, let name = alert.textFields?.first?.text, !name.isEmpty else { return }
            let full = (self.active_pane.current_path as NSString).appendingPathComponent(name)
            do {
                if is_directory {
                    try FileSystemProvider.shared.create_directory(at: full)
                } else {
                    try FileSystemProvider.shared.create_file(at: full)
                }
                self.active_pane.reload()
            } catch {
                let err_alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                err_alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(err_alert, animated: true)
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present_adaptive_sheet(alert)
    }

    @objc private func open_sidebar() {
        let side_vc = SideDrawerViewController()
        side_vc.on_select_location = { [weak self] path in
            self?.active_pane.navigate_to(path: path)
        }
        side_vc.on_open_mcp = { [weak self] in
            let mcp_vc = McpServerViewController()
            self?.present(UINavigationController(rootViewController: mcp_vc), animated: true)
        }
        side_vc.on_open_network = { [weak self] in
            let net_vc = NetworkStorageViewController()
            self?.present(UINavigationController(rootViewController: net_vc), animated: true)
        }
        side_vc.on_open_ftp_server = { [weak self] in
            let ftp_vc = FtpServerViewController()
            self?.present(UINavigationController(rootViewController: ftp_vc), animated: true)
        }
        side_vc.on_open_app_manager = { [weak self] in
            let app_vc = AppManagerViewController()
            app_vc.on_navigate_to_path = { [weak self] path in
                self?.active_pane.navigate_to(path: path)
            }
            self?.present(UINavigationController(rootViewController: app_vc), animated: true)
        }
        side_vc.on_open_storage_manager = { [weak self] in
            let stor_vc = StorageManagerViewController()
            stor_vc.on_locate_file = { [weak self] path in
                self?.active_pane.navigate_to(path: path)
            }
            self?.present(UINavigationController(rootViewController: stor_vc), animated: true)
        }
        side_vc.on_open_wifi_manager = { [weak self] in
            let wifi_vc = WifiManagerViewController()
            self?.present(UINavigationController(rootViewController: wifi_vc), animated: true)
        }
        side_vc.on_open_shell_runner = { [weak self] in
            let sh_vc = ShellRunnerViewController()
            self?.present(UINavigationController(rootViewController: sh_vc), animated: true)
        }
        side_vc.on_open_command_helper = { [weak self] in
            guard let self = self else { return }
            let sel = self.active_pane.current_selected_items.first
            let cmd_vc = CommandHelperViewController(target_item: sel)
            self.present(UINavigationController(rootViewController: cmd_vc), animated: true)
        }
        side_vc.on_open_settings = { [weak self] in
            let set_vc = SettingsViewController()
            self?.present(UINavigationController(rootViewController: set_vc), animated: true)
        }
        present(UINavigationController(rootViewController: side_vc), animated: true)
    }

    @objc private func open_bookmarks_drawer() {
        let drawer_vc = BookmarksDrawerViewController(pane_id: active_pane_id, current_path: active_pane.current_path)
        drawer_vc.on_select_path = { [weak self] path in
            self?.active_pane.navigate_to(path: path)
        }
        if let sheet = drawer_vc.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(drawer_vc, animated: true)
    }

    @objc private func open_more_menu() {
        let sheet = UIAlertController(title: "Tools & Options", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Installed Apps & Containers", style: .default, handler: { [weak self] _ in
            let app_vc = AppManagerViewController()
            app_vc.on_navigate_to_path = { [weak self] path in
                self?.active_pane.navigate_to(path: path)
            }
            self?.present(UINavigationController(rootViewController: app_vc), animated: true)
        }))
        sheet.addAction(UIAlertAction(title: "Storage Manager", style: .default, handler: { [weak self] _ in
            let stor_vc = StorageManagerViewController()
            stor_vc.on_locate_file = { [weak self] path in
                self?.active_pane.navigate_to(path: path)
            }
            self?.present(UINavigationController(rootViewController: stor_vc), animated: true)
        }))
        sheet.addAction(UIAlertAction(title: "Wi-Fi & Network Manager", style: .default, handler: { [weak self] _ in
            let wifi_vc = WifiManagerViewController()
            self?.present(UINavigationController(rootViewController: wifi_vc), animated: true)
        }))
        sheet.addAction(UIAlertAction(title: "Shell Command Runner", style: .default, handler: { [weak self] _ in
            let sh_vc = ShellRunnerViewController()
            self?.present(UINavigationController(rootViewController: sh_vc), animated: true)
        }))
        sheet.addAction(UIAlertAction(title: "Command Helper", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            let sel = self.active_pane.current_selected_items.first
            let cmd_vc = CommandHelperViewController(target_item: sel)
            self.present(UINavigationController(rootViewController: cmd_vc), animated: true)
        }))
        sheet.addAction(UIAlertAction(title: "Bookmarks & History", style: .default, handler: { [weak self] _ in
            self?.open_bookmarks_drawer()
        }))
        sheet.addAction(UIAlertAction(title: "Search Current Folder", style: .default, handler: { [weak self] _ in
            self?.open_search_dialog()
        }))
        sheet.addAction(UIAlertAction(title: "Compare Panes (Diff)", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            let sel1 = self.pane1_vc.current_selected_items
            let sel2 = self.pane2_vc.current_selected_items
            if sel1.count == 1 && sel2.count == 1 {
                let diff_vc = FileDiffViewController(path_left: sel1[0].path, path_right: sel2[0].path)
                self.present(UINavigationController(rootViewController: diff_vc), animated: true)
            } else {
                let alert = UIAlertController(title: "Compare", message: "Please select 1 file in Pane 1 and 1 file in Pane 2 to compare.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }))
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present_adaptive_sheet(sheet, bar_button_item: navigationItem.rightBarButtonItem)
    }

    private func open_search_dialog() {
        let search_vc = SearchDialogViewController(root_path: active_pane.current_path)
        search_vc.on_select_file = { [weak self] item in
            self?.open_file(item)
        }
        present(UINavigationController(rootViewController: search_vc), animated: true)
    }

    private func open_file(_ item: FileItem) {
        let ext = item.file_extension

        if item.name.hasSuffix(".bak") {
            let alert = UIAlertController(title: "Restore Backup", message: "Do you want to restore '\(item.name)' to its original file?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Restore", style: .destructive, handler: { [weak self] _ in
                let original_path = (item.path as NSString).deletingPathExtension
                do {
                    if FileManager.default.fileExists(atPath: original_path) {
                        try FileManager.default.removeItem(atPath: original_path)
                    }
                    try FileManager.default.copyItem(atPath: item.path, toPath: original_path)
                    self?.active_pane.reload()
                } catch {
                    let err = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                    err.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(err, animated: true)
                }
            }))
            alert.addAction(UIAlertAction(title: "Open in Editor", style: .default, handler: { [weak self] _ in
                let edit_vc = TextEditorViewController(file_path: item.path)
                self?.present(UINavigationController(rootViewController: edit_vc), animated: true)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
            return
        }

        if ["mp3", "wav", "m4a", "aac", "flac", "ogg", "wma", "mp4", "mov", "m4v", "mkv", "avi", "webm"].contains(ext) {
            let player_vc = AudioVideoPlayerViewController(media_path: item.path)
            player_vc.modalPresentationStyle = .fullScreen
            present(player_vc, animated: true)
            return
        }

        if ["png", "jpg", "jpeg", "gif", "webp", "heic", "svg", "bmp", "tiff"].contains(ext) {
            let dir = (item.path as NSString).deletingLastPathComponent
            let all_images = (try? FileManager.default.contentsOfDirectory(atPath: dir))?.filter {
                let e = ($0 as NSString).pathExtension.lowercased()
                return ["png", "jpg", "jpeg", "gif", "webp", "heic", "svg", "bmp", "tiff"].contains(e)
            }.map { (dir as NSString).appendingPathComponent($0) } ?? [item.path]
            let viewer = ImageViewerViewController(current_path: item.path, all_image_paths: all_images)
            viewer.modalPresentationStyle = .fullScreen
            present(viewer, animated: true)
            return
        }

        if ext == "pdf" {
            let pdf_vc = PdfViewerViewController(pdf_path: item.path)
            present(UINavigationController(rootViewController: pdf_vc), animated: true)
            return
        }

        if ["sh", "bash", "zsh", "command"].contains(ext) {
            let alert = UIAlertController(title: item.name, message: "Shell Script Actions:", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Run in Terminal", style: .default, handler: { [weak self] _ in
                let sh_vc = ShellRunnerViewController(script_path: item.path)
                self?.present(UINavigationController(rootViewController: sh_vc), animated: true)
            }))
            alert.addAction(UIAlertAction(title: "Edit Script", style: .default, handler: { [weak self] _ in
                let edit_vc = TextEditorViewController(file_path: item.path)
                self?.present(UINavigationController(rootViewController: edit_vc), animated: true)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
            return
        }

        if ext == "apk" {
            let apk_vc = ApkInfoViewController(apk_path: item.path)
            apk_vc.on_browse_apk = { [weak self] path in
                self?.active_pane.navigate_to(path: path)
            }
            present(UINavigationController(rootViewController: apk_vc), animated: true)
            return
        }

        if ext == "sqlite" || ext == "db" || ext == "sqlite3" {
            let sql_vc = SQLiteBrowserViewController(db_path: item.path)
            present(UINavigationController(rootViewController: sql_vc), animated: true)
            return
        }

        if ["zip", "7z", "rar", "tar", "gz", "bz2", "xz"].contains(ext) {
            prompt_archive_action(item)
            return
        }

        let is_binary = ["dex", "so", "dylib", "elf", "o", "a", "bin"].contains(ext)
        if is_binary {
            let alert = UIAlertController(title: item.name, message: "Choose binary inspection tool:", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Hex Editor", style: .default, handler: { [weak self] _ in
                let hex_vc = HexEditorViewController(file_path: item.path)
                self?.present(UINavigationController(rootViewController: hex_vc), animated: true)
            }))
            alert.addAction(UIAlertAction(title: "Mach-O / ELF Inspector", style: .default, handler: { [weak self] _ in
                self?.inspect_macho(item.path)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
            return
        }

        let edit_vc = TextEditorViewController(file_path: item.path)
        present(UINavigationController(rootViewController: edit_vc), animated: true)
    }

    private func inspect_macho(_ path: String) {
        do {
            let info = try MachOInspector.shared.inspect(at: path)
            let msg = """
            Architecture: \(info.architecture)
            Type: \(info.file_type)
            Load Commands: \(info.load_commands_count)
            Target: \(info.platform) (MinOS: \(info.min_os), SDK: \(info.sdk_version))
            Segments: \(info.segments.joined(separator: ", "))
            Linked Dylibs (\(info.linked_dylibs.count)): \(info.linked_dylibs.prefix(5).joined(separator: ", "))
            """
            let alert = UIAlertController(title: (path as NSString).lastPathComponent, message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        } catch {
            let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    private func prompt_archive_action(_ item: FileItem) {
        let alert = UIAlertController(title: item.name, message: "Archive Options:", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Extract into Other Pane", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            let dest = self.inactive_pane.current_path
            Task {
                do {
                    try ArchiveManager.extract_archive(at: item.path, to: dest)
                    await MainActor.run { self.inactive_pane.reload() }
                } catch {
                    await MainActor.run {
                        let err_alert = UIAlertController(title: "Extraction Error", message: error.localizedDescription, preferredStyle: .alert)
                        err_alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(err_alert, animated: true)
                    }
                }
            }
        }))
        alert.addAction(UIAlertAction(title: "Extract into Current Folder", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            let dest = self.active_pane.current_path
            Task {
                do {
                    try ArchiveManager.extract_archive(at: item.path, to: dest)
                    await MainActor.run { self.active_pane.reload() }
                } catch {
                    await MainActor.run {
                        let err_alert = UIAlertController(title: "Extraction Error", message: error.localizedDescription, preferredStyle: .alert)
                        err_alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(err_alert, animated: true)
                    }
                }
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present_adaptive_sheet(alert)
    }
}

extension DualPaneViewController: MainFilesPaneDelegate {
    public func pane_did_gain_focus(pane_id: Int) {
        if active_pane_id != pane_id {
            update_active_pane(pane_id)
        }
    }

    public func pane_did_change_path(path: String, item_count: Int, from pane_id: Int) {
        if active_pane_id == pane_id {
            path_label.text = path
            count_label.text = "\(item_count) items"
        }
    }

    public func pane_did_request_open_file(item: FileItem, from pane_id: Int) {
        open_file(item)
    }

    public func pane_did_request_context_menu(items: [FileItem], from pane_id: Int) {
        let count = items.count
        guard count > 0 else { return }
        let alert = UIAlertController(title: count == 1 ? items[0].name : "\(count) Items Selected", message: nil, preferredStyle: .actionSheet)

        let target_dir = inactive_pane.current_path

        alert.addAction(UIAlertAction(title: "Copy -> Other Pane", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            let paths = items.map { $0.path }
            Task {
                do {
                    _ = try await FileOperationsQueue.shared.copy_items(sources: paths, destination_directory: target_dir)
                    await MainActor.run { self.inactive_pane.reload(); self.active_pane.clear_selection() }
                } catch {
                    await MainActor.run {
                        let err_alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                        err_alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(err_alert, animated: true)
                    }
                }
            }
        }))

        alert.addAction(UIAlertAction(title: "Move -> Other Pane", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            let paths = items.map { $0.path }
            Task {
                do {
                    _ = try await FileOperationsQueue.shared.move_items(sources: paths, destination_directory: target_dir)
                    await MainActor.run { self.inactive_pane.reload(); self.active_pane.reload(); self.active_pane.clear_selection() }
                } catch {
                    await MainActor.run {
                        let err_alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                        err_alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(err_alert, animated: true)
                    }
                }
            }
        }))

        if count == 1 {
            alert.addAction(UIAlertAction(title: "Rename", style: .default, handler: { [weak self] _ in
                self?.prompt_rename(items[0])
            }))
            alert.addAction(UIAlertAction(title: "Properties", style: .default, handler: { [weak self] _ in
                let prop_vc = FilePropertiesViewController(item: items[0])
                prop_vc.on_permissions_changed = { [weak self] in
                    self?.active_pane.reload()
                }
                self?.present(UINavigationController(rootViewController: prop_vc), animated: true)
            }))
            alert.addAction(UIAlertAction(title: "Command Helper...", style: .default, handler: { [weak self] _ in
                let cmd_vc = CommandHelperViewController(target_item: items[0])
                self?.present(UINavigationController(rootViewController: cmd_vc), animated: true)
            }))
            if ["sh", "bash", "zsh", "command"].contains(items[0].file_extension) {
                alert.addAction(UIAlertAction(title: "Run in Terminal", style: .default, handler: { [weak self] _ in
                    let runner = ShellRunnerViewController(script_path: items[0].path)
                    self?.present(UINavigationController(rootViewController: runner), animated: true)
                }))
            }
        } else if count > 1 {
            alert.addAction(UIAlertAction(title: "Batch Rename...", style: .default, handler: { [weak self] _ in
                let batch_vc = BatchRenameViewController(items: items)
                batch_vc.on_completed = { [weak self] in
                    self?.active_pane.reload()
                }
                self?.present(UINavigationController(rootViewController: batch_vc), animated: true)
            }))
        }

        alert.addAction(UIAlertAction(title: "Add to ZIP", style: .default, handler: { [weak self] _ in
            self?.prompt_compress(items)
        }))

        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            self?.prompt_delete(items)
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { [weak self] _ in
            self?.active_pane.clear_selection()
        }))

        present(alert, animated: true)
    }

    private func prompt_rename(_ item: FileItem) {
        let alert = UIAlertController(title: "Rename", message: "Enter new name:", preferredStyle: .alert)
        alert.addTextField { $0.text = item.name }
        alert.addAction(UIAlertAction(title: "Rename", style: .default, handler: { [weak self] _ in
            guard let self = self, let new_name = alert.textFields?.first?.text, !new_name.isEmpty else { return }
            do {
                try FileOperationsQueue.shared.rename_item(at: item.path, to: new_name)
                self.active_pane.reload()
            } catch {
                let err_alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                err_alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(err_alert, animated: true)
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present_adaptive_sheet(alert)
    }

    private func prompt_compress(_ items: [FileItem]) {
        let first = items[0].name
        let zip_name = items.count == 1 ? (first as NSString).deletingPathExtension + ".zip" : "Archive.zip"
        let dest = (active_pane.current_path as NSString).appendingPathComponent(zip_name)
        Task {
            do {
                try ArchiveManager.create_archive(sources: items.map { $0.path }, destination_path: dest, format: .zip)
                await MainActor.run { self.active_pane.reload() }
            } catch {
                await MainActor.run {
                    let err_alert = UIAlertController(title: "Compress Error", message: error.localizedDescription, preferredStyle: .alert)
                    err_alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(err_alert, animated: true)
                }
            }
        }
    }

    private func prompt_delete(_ items: [FileItem]) {
        let count = items.count
        let msg = count == 1 ? "Permanently delete '\(items[0].name)'?" : "Permanently delete \(count) items?"
        let alert = UIAlertController(title: "Confirm Deletion", message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            guard let self = self else { return }
            let paths = items.map { $0.path }
            Task {
                do {
                    _ = try await FileOperationsQueue.shared.delete(paths: paths)
                    await MainActor.run { self.active_pane.reload(); self.active_pane.clear_selection() }
                } catch {
                    await MainActor.run {
                        let err_alert = UIAlertController(title: "Delete Error", message: error.localizedDescription, preferredStyle: .alert)
                        err_alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(err_alert, animated: true)
                    }
                }
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present_adaptive_sheet(alert)
    }
}
