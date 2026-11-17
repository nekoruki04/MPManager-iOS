import UIKit

public final class SideDrawerViewController: UIViewController {
    public var on_select_location: ((String) -> Void)?
    public var on_open_mcp: (() -> Void)?
    public var on_open_network: (() -> Void)?
    public var on_open_ftp_server: (() -> Void)?
    public var on_open_app_manager: (() -> Void)?
    public var on_open_storage_manager: (() -> Void)?
    public var on_open_wifi_manager: (() -> Void)?
    public var on_open_shell_runner: (() -> Void)?
    public var on_open_command_helper: (() -> Void)?
    public var on_open_settings: (() -> Void)?

    private let scroll_view = UIScrollView()
    private let content_stack = UIStackView()

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "Navigation"
        view.backgroundColor = MPTheme.surface_dark

        setup_ui()
    }

    private func setup_ui() {
        scroll_view.translatesAutoresizingMaskIntoConstraints = false
        content_stack.translatesAutoresizingMaskIntoConstraints = false
        content_stack.axis = .vertical
        content_stack.spacing = 16

        view.addSubview(scroll_view)
        scroll_view.addSubview(content_stack)

        NSLayoutConstraint.activate([
            scroll_view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll_view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll_view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll_view.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            content_stack.topAnchor.constraint(equalTo: scroll_view.topAnchor, constant: 16),
            content_stack.leadingAnchor.constraint(equalTo: scroll_view.leadingAnchor, constant: 16),
            content_stack.trailingAnchor.constraint(equalTo: scroll_view.trailingAnchor, constant: -16),
            content_stack.bottomAnchor.constraint(equalTo: scroll_view.bottomAnchor, constant: -16),
            content_stack.widthAnchor.constraint(equalTo: scroll_view.widthAnchor, constant: -32)
        ])

        add_header()
        add_storage_section()
        add_tools_section()
    }

    private func add_header() {
        let header = UIStackView()
        header.axis = .horizontal
        header.spacing = 12
        header.alignment = .center

        let icon = UIImageView(image: UIImage(systemName: "folder.badge.gearshape")?.withTintColor(MPTheme.primary_accent, renderingMode: .alwaysOriginal))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 36).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 36).isActive = true
        header.addArrangedSubview(icon)

        let title_stack = UIStackView()
        title_stack.axis = .vertical
        let app_title = UILabel()
        app_title.text = "MP Manager"
        app_title.font = UIFont.boldSystemFont(ofSize: 18)
        app_title.textColor = MPTheme.text_primary
        let flavor_label = UILabel()
        flavor_label.text = JailbreakEnvironment.current_flavor.description
        flavor_label.font = UIFont.systemFont(ofSize: 12)
        flavor_label.textColor = MPTheme.secondary_accent
        title_stack.addArrangedSubview(app_title)
        title_stack.addArrangedSubview(flavor_label)

        header.addArrangedSubview(title_stack)
        content_stack.addArrangedSubview(header)
    }

    private func add_storage_section() {
        let sec_label = UILabel()
        sec_label.text = "Storage"
        sec_label.font = UIFont.boldSystemFont(ofSize: 14)
        sec_label.textColor = MPTheme.text_secondary
        content_stack.addArrangedSubview(sec_label)

        let storages = [
            ("Internal Storage", "/var/mobile", "internaldrive.fill"),
            ("Jailbreak (/var/jb)", RootlessPaths.resolved_jailbreak_path, "wrench.and.screwdriver.fill"),
            ("Media & Downloads", "/var/mobile/Media", "photo.on.rectangle.angled"),
            ("Root Directory", "/", "shield.fill")
        ]

        for (title, path, icon_name) in storages {
            let (tot, free) = FileSystemProvider.shared.storage_space(at: path)
            let used = tot - free
            let frac = tot > 0 ? Float(used) / Float(tot) : 0.0

            let box = UIStackView()
            box.axis = .vertical
            box.spacing = 4
            box.backgroundColor = MPTheme.background_dark
            box.isLayoutMarginsRelativeArrangement = true
            box.layoutMargins = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
            box.layer.cornerRadius = 8

            let top_row = UIStackView()
            top_row.axis = .horizontal

            let icon = UIImageView(image: UIImage(systemName: icon_name)?.withTintColor(MPTheme.primary_accent, renderingMode: .alwaysOriginal))
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.widthAnchor.constraint(equalToConstant: 20).isActive = true
            icon.heightAnchor.constraint(equalToConstant: 20).isActive = true
            top_row.addArrangedSubview(icon)

            let name_lbl = UILabel()
            name_lbl.text = "  " + title
            name_lbl.textColor = MPTheme.text_primary
            name_lbl.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            top_row.addArrangedSubview(name_lbl)

            let free_lbl = UILabel()
            let free_gb = Double(free) / (1024 * 1024 * 1024)
            let tot_gb = Double(tot) / (1024 * 1024 * 1024)
            free_lbl.text = String(format: "%.1f / %.1f GB", tot_gb - free_gb, tot_gb)
            free_lbl.textColor = MPTheme.text_secondary
            free_lbl.font = UIFont.systemFont(ofSize: 12)
            free_lbl.textAlignment = .right
            top_row.addArrangedSubview(free_lbl)

            box.addArrangedSubview(top_row)

            let progress = UIProgressView(progressViewStyle: .bar)
            progress.progress = frac
            progress.progressTintColor = frac > 0.9 ? UIColor.systemRed : MPTheme.primary_accent
            progress.trackTintColor = MPTheme.surface_variant
            progress.layer.cornerRadius = 2
            progress.clipsToBounds = true
            box.addArrangedSubview(progress)

            let tap = UITapGestureRecognizer(target: self, action: #selector(storage_tapped(_:)))
            box.addGestureRecognizer(tap)
            box.isUserInteractionEnabled = true
            box.accessibilityIdentifier = path

            content_stack.addArrangedSubview(box)
        }
    }

    private func add_tools_section() {
        let sec_label = UILabel()
        sec_label.text = "Tools & Services"
        sec_label.font = UIFont.boldSystemFont(ofSize: 14)
        sec_label.textColor = MPTheme.text_secondary
        content_stack.addArrangedSubview(sec_label)

        let tools: [(String, String, Selector)] = [
            ("Installed Apps & Containers", "square.stack.3d.up.fill", #selector(open_app_manager_tapped)),
            ("Storage Manager", "chart.pie.fill", #selector(open_storage_manager_tapped)),
            ("Wi-Fi & Network Manager", "wifi", #selector(open_wifi_manager_tapped)),
            ("Shell Command Runner", "terminal.fill", #selector(open_shell_runner_tapped)),
            ("Command Helper", "applescript.fill", #selector(open_command_helper_tapped)),
            ("FTP Server (Wireless Transfer)", "antenna.radiowaves.left.and.right", #selector(open_ftp_server_tapped)),
            ("Network Storage (WebDAV/FTP)", "network", #selector(open_network_tapped)),
            ("MCP Service (AI Tools)", "cpu.fill", #selector(open_mcp_tapped)),
            ("Settings & Preferences", "gearshape.fill", #selector(open_settings_tapped))
        ]

        for (name, icon_name, action) in tools {
            let btn = UIButton(type: .system)
            btn.backgroundColor = MPTheme.background_dark
            btn.layer.cornerRadius = 8
            btn.contentHorizontalAlignment = .left
            btn.contentEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
            btn.setImage(UIImage(systemName: icon_name)?.withTintColor(MPTheme.secondary_accent, renderingMode: .alwaysOriginal), for: .normal)
            btn.setTitle("   " + name, for: .normal)
            btn.setTitleColor(MPTheme.text_primary, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            btn.addTarget(self, action: action, for: .touchUpInside)
            content_stack.addArrangedSubview(btn)
        }
    }

    @objc private func storage_tapped(_ gesture: UITapGestureRecognizer) {
        guard let path = gesture.view?.accessibilityIdentifier else { return }
        dismiss(animated: true) { [weak self] in
            self?.on_select_location?(path)
        }
    }

    @objc private func open_app_manager_tapped() {
        dismiss(animated: true) { [weak self] in
            self?.on_open_app_manager?()
        }
    }

    @objc private func open_storage_manager_tapped() {
        dismiss(animated: true) { [weak self] in
            self?.on_open_storage_manager?()
        }
    }

    @objc private func open_wifi_manager_tapped() {
        dismiss(animated: true) { [weak self] in
            self?.on_open_wifi_manager?()
        }
    }

    @objc private func open_shell_runner_tapped() {
        dismiss(animated: true) { [weak self] in
            self?.on_open_shell_runner?()
        }
    }

    @objc private func open_command_helper_tapped() {
        dismiss(animated: true) { [weak self] in
            self?.on_open_command_helper?()
        }
    }

    @objc private func open_mcp_tapped() {
        dismiss(animated: true) { [weak self] in
            self?.on_open_mcp?()
        }
    }

    @objc private func open_network_tapped() {
        dismiss(animated: true) { [weak self] in
            self?.on_open_network?()
        }
    }

    @objc private func open_ftp_server_tapped() {
        dismiss(animated: true) { [weak self] in
            self?.on_open_ftp_server?()
        }
    }

    @objc private func open_settings_tapped() {
        dismiss(animated: true) { [weak self] in
            self?.on_open_settings?()
        }
    }
}
