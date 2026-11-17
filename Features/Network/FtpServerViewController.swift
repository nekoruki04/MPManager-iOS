import UIKit

public final class FtpServerViewController: UIViewController {
    private let status_badge = UIView()
    private let status_label = UILabel()
    private let url_label = UILabel()
    private let client_count_label = UILabel()
    private let port_field = UITextField()
    private let root_field = UITextField()
    private let anonymous_switch = UISwitch()
    private let user_field = UITextField()
    private let pass_field = UITextField()
    private let toggle_button = UIButton(type: .system)
    private let log_view = UITextView()
    private var logs: [String] = []

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "FTP Server (Wireless)"
        view.backgroundColor = MPTheme.background_dark

        setup_navigation()
        setup_ui()
        bind_server()
        update_state()
    }

    private func setup_navigation() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Share", style: .plain, target: self, action: #selector(share_url))
    }

    private func setup_ui() {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)

        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 16
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            content.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 16),
            content.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -16),
            content.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -32)
        ])

        setup_status_card(content)
        setup_configuration_section(content)
        setup_action_button(content)
        setup_log_section(content)
    }

    private func setup_status_card(_ parent: UIStackView) {
        let card = UIView()
        card.backgroundColor = MPTheme.surface_dark
        card.layer.cornerRadius = 12
        card.layer.borderColor = MPTheme.border_color.cgColor
        card.layer.borderWidth = 1

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        let top_row = UIStackView()
        top_row.axis = .horizontal
        top_row.spacing = 8
        top_row.alignment = .center

        status_badge.translatesAutoresizingMaskIntoConstraints = false
        status_badge.widthAnchor.constraint(equalToConstant: 12).isActive = true
        status_badge.heightAnchor.constraint(equalToConstant: 12).isActive = true
        status_badge.layer.cornerRadius = 6
        status_badge.backgroundColor = UIColor.systemGray
        top_row.addArrangedSubview(status_badge)

        status_label.font = UIFont.boldSystemFont(ofSize: 16)
        status_label.textColor = MPTheme.text_primary
        status_label.text = "FTP Server: Inactive"
        top_row.addArrangedSubview(status_label)

        stack.addArrangedSubview(top_row)

        url_label.font = UIFont.monospacedSystemFont(ofSize: 15, weight: .bold)
        url_label.textColor = MPTheme.primary_accent
        url_label.numberOfLines = 0
        stack.addArrangedSubview(url_label)

        client_count_label.font = UIFont.systemFont(ofSize: 12)
        client_count_label.textColor = MPTheme.text_secondary
        client_count_label.text = "Connected clients: 0"
        stack.addArrangedSubview(client_count_label)

        let copy_btn = UIButton(type: .system)
        copy_btn.setTitle("Copy Server URL", for: .normal)
        copy_btn.setTitleColor(MPTheme.secondary_accent, for: .normal)
        copy_btn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        copy_btn.contentHorizontalAlignment = .left
        copy_btn.addTarget(self, action: #selector(copy_url), for: .touchUpInside)
        stack.addArrangedSubview(copy_btn)

        parent.addArrangedSubview(card)
    }

    private func setup_configuration_section(_ parent: UIStackView) {
        let sec_title = UILabel()
        sec_title.text = "Server Configuration"
        sec_title.font = UIFont.boldSystemFont(ofSize: 14)
        sec_title.textColor = MPTheme.text_secondary
        parent.addArrangedSubview(sec_title)

        let box = UIStackView()
        box.axis = .vertical
        box.spacing = 12
        box.backgroundColor = MPTheme.surface_dark
        box.layer.cornerRadius = 10
        box.isLayoutMarginsRelativeArrangement = true
        box.layoutMargins = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)

        let port_row = create_input_row(label: "Port:", field: port_field, default_text: "\(FtpServer.shared.port)")
        box.addArrangedSubview(port_row)

        let root_row = create_input_row(label: "Root Path:", field: root_field, default_text: FtpServer.shared.root_directory)
        box.addArrangedSubview(root_row)

        let anon_row = UIStackView()
        anon_row.axis = .horizontal
        let anon_lbl = UILabel()
        anon_lbl.text = "Anonymous Access"
        anon_lbl.textColor = MPTheme.text_primary
        anon_lbl.font = UIFont.systemFont(ofSize: 14)
        anon_row.addArrangedSubview(anon_lbl)
        anonymous_switch.isOn = FtpServer.shared.allow_anonymous
        anonymous_switch.onTintColor = MPTheme.primary_accent
        anon_row.addArrangedSubview(anonymous_switch)
        box.addArrangedSubview(anon_row)

        let user_row = create_input_row(label: "Username:", field: user_field, default_text: FtpServer.shared.required_username)
        box.addArrangedSubview(user_row)

        let pass_row = create_input_row(label: "Password:", field: pass_field, default_text: FtpServer.shared.required_password)
        pass_field.isSecureTextEntry = true
        box.addArrangedSubview(pass_row)

        parent.addArrangedSubview(box)
    }

    private func create_input_row(label: String, field: UITextField, default_text: String) -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .center

        let lbl = UILabel()
        lbl.text = label
        lbl.textColor = MPTheme.text_primary
        lbl.font = UIFont.systemFont(ofSize: 14)
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.widthAnchor.constraint(equalToConstant: 90).isActive = true
        row.addArrangedSubview(lbl)

        field.text = default_text
        field.textColor = MPTheme.text_primary
        field.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        field.backgroundColor = MPTheme.background_dark
        field.layer.cornerRadius = 6
        field.layer.borderColor = MPTheme.border_color.cgColor
        field.layer.borderWidth = 1
        field.heightAnchor.constraint(equalToConstant: 34).isActive = true
        row.addArrangedSubview(field)

        return row
    }

    private func setup_action_button(_ parent: UIStackView) {
        toggle_button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        toggle_button.layer.cornerRadius = 8
        toggle_button.translatesAutoresizingMaskIntoConstraints = false
        toggle_button.heightAnchor.constraint(equalToConstant: 46).isActive = true
        toggle_button.addTarget(self, action: #selector(toggle_server), for: .touchUpInside)
        parent.addArrangedSubview(toggle_button)
    }

    private func setup_log_section(_ parent: UIStackView) {
        let sec_title = UILabel()
        sec_title.text = "Session & Transfer Logs"
        sec_title.font = UIFont.boldSystemFont(ofSize: 14)
        sec_title.textColor = MPTheme.text_secondary
        parent.addArrangedSubview(sec_title)

        log_view.backgroundColor = MPTheme.surface_dark
        log_view.textColor = MPTheme.text_primary
        log_view.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        log_view.isEditable = false
        log_view.layer.cornerRadius = 8
        log_view.layer.borderColor = MPTheme.border_color.cgColor
        log_view.layer.borderWidth = 1
        log_view.translatesAutoresizingMaskIntoConstraints = false
        log_view.heightAnchor.constraint(equalToConstant: 160).isActive = true
        parent.addArrangedSubview(log_view)
    }

    private func bind_server() {
        FtpServer.shared.on_log_message = { [weak self] msg in
            guard let self = self else { return }
            self.logs.append(msg)
            if self.logs.count > 200 { self.logs.removeFirst() }
            self.log_view.text = self.logs.joined(separator: "\n")
            if !self.logs.isEmpty {
                let range = NSRange(location: self.log_view.text.count - 1, length: 1)
                self.log_view.scrollRangeToVisible(range)
            }
        }

        FtpServer.shared.on_client_count_changed = { [weak self] count in
            self?.client_count_label.text = "Connected clients: \(count)"
        }
    }

    private func update_state() {
        let running = FtpServer.shared.is_running
        status_badge.backgroundColor = running ? UIColor.systemGreen : UIColor.systemGray
        status_label.text = running ? "FTP Server: Running" : "FTP Server: Inactive"

        let ip = FtpServer.shared.get_wifi_address() ?? "127.0.0.1"
        let url = "ftp://\(ip):\(FtpServer.shared.port)/"
        url_label.text = running ? url : "Ready to start at ftp://\(ip):\(port_field.text ?? "2121")/"

        toggle_button.setTitle(running ? "Stop FTP Server" : "Start FTP Server", for: .normal)
        toggle_button.backgroundColor = running ? UIColor.systemRed : MPTheme.secondary_accent
        toggle_button.setTitleColor(.white, for: .normal)

        port_field.isEnabled = !running
        root_field.isEnabled = !running
        anonymous_switch.isEnabled = !running
        user_field.isEnabled = !running
        pass_field.isEnabled = !running
    }

    @objc private func toggle_server() {
        if FtpServer.shared.is_running {
            FtpServer.shared.stop()
        } else {
            let port_str = port_field.text ?? "2121"
            let port = UInt16(port_str) ?? 2121
            let root = root_field.text ?? "/var/mobile"
            FtpServer.shared.allow_anonymous = anonymous_switch.isOn
            FtpServer.shared.required_username = user_field.text ?? "admin"
            FtpServer.shared.required_password = pass_field.text ?? "admin"

            do {
                try FtpServer.shared.start(port: port, root: root)
            } catch {
                let alert = UIAlertController(title: "Startup Error", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }
        update_state()
    }

    @objc private func copy_url() {
        let ip = FtpServer.shared.get_wifi_address() ?? "127.0.0.1"
        let url = "ftp://\(ip):\(FtpServer.shared.port)/"
        UIPasteboard.general.string = url

        let alert = UIAlertController(title: "Copied", message: url, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func share_url() {
        let ip = FtpServer.shared.get_wifi_address() ?? "127.0.0.1"
        let url = "ftp://\(ip):\(FtpServer.shared.port)/"
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let pop = av.popoverPresentationController {
            pop.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(av, animated: true)
    }
}
