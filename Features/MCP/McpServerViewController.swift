import UIKit

public final class McpServerViewController: UIViewController {
    private let status_card = UIView()
    private let status_badge = UIView()
    private let status_label = UILabel()
    private let url_label = UILabel()
    private let port_field = UITextField()
    private let toggle_button = UIButton(type: .system)
    private let log_view = UITextView()
    private var logs: [String] = []

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "MCP Service"
        view.backgroundColor = MPTheme.background_dark

        setup_navigation()
        setup_ui()
        bind_server_logs()
        update_state()
    }

    private func setup_navigation() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Config JSON", style: .plain, target: self, action: #selector(show_claude_config))
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

        setup_card(content)
        setup_controls(content)
        setup_log_viewer(content)
        setup_tools_preview(content)
    }

    private func setup_card(_ parent: UIStackView) {
        status_card.backgroundColor = MPTheme.surface_dark
        status_card.layer.cornerRadius = 12
        status_card.layer.borderColor = MPTheme.border_color.cgColor
        status_card.layer.borderWidth = 1

        let card_stack = UIStackView()
        card_stack.axis = .vertical
        card_stack.spacing = 10
        card_stack.translatesAutoresizingMaskIntoConstraints = false
        status_card.addSubview(card_stack)

        NSLayoutConstraint.activate([
            card_stack.topAnchor.constraint(equalTo: status_card.topAnchor, constant: 16),
            card_stack.leadingAnchor.constraint(equalTo: status_card.leadingAnchor, constant: 16),
            card_stack.trailingAnchor.constraint(equalTo: status_card.trailingAnchor, constant: -16),
            card_stack.bottomAnchor.constraint(equalTo: status_card.bottomAnchor, constant: -16)
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
        status_label.text = "MCP Server: Inactive"
        top_row.addArrangedSubview(status_label)

        card_stack.addArrangedSubview(top_row)

        url_label.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        url_label.textColor = MPTheme.primary_accent
        url_label.numberOfLines = 0
        card_stack.addArrangedSubview(url_label)

        let copy_btn = UIButton(type: .system)
        copy_btn.setTitle("Copy Endpoint URL", for: .normal)
        copy_btn.setTitleColor(MPTheme.secondary_accent, for: .normal)
        copy_btn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        copy_btn.contentHorizontalAlignment = .left
        copy_btn.addTarget(self, action: #selector(copy_url), for: .touchUpInside)
        card_stack.addArrangedSubview(copy_btn)

        parent.addArrangedSubview(status_card)
    }

    private func setup_controls(_ parent: UIStackView) {
        let port_row = UIStackView()
        port_row.axis = .horizontal
        port_row.spacing = 12
        port_row.alignment = .center

        let port_lbl = UILabel()
        port_lbl.text = "Port:"
        port_lbl.textColor = MPTheme.text_primary
        port_lbl.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        port_row.addArrangedSubview(port_lbl)

        port_field.text = "\(McpServer.shared.port)"
        port_field.keyboardType = .numberPad
        port_field.backgroundColor = MPTheme.surface_dark
        port_field.textColor = MPTheme.text_primary
        port_field.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        port_field.layer.cornerRadius = 6
        port_field.layer.borderColor = MPTheme.border_color.cgColor
        port_field.layer.borderWidth = 1
        port_field.translatesAutoresizingMaskIntoConstraints = false
        port_field.widthAnchor.constraint(equalToConstant: 80).isActive = true
        port_field.heightAnchor.constraint(equalToConstant: 36).isActive = true
        port_field.textAlignment = .center
        port_row.addArrangedSubview(port_field)

        let spacer = UIView()
        port_row.addArrangedSubview(spacer)

        parent.addArrangedSubview(port_row)

        toggle_button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        toggle_button.layer.cornerRadius = 8
        toggle_button.translatesAutoresizingMaskIntoConstraints = false
        toggle_button.heightAnchor.constraint(equalToConstant: 46).isActive = true
        toggle_button.addTarget(self, action: #selector(toggle_server), for: .touchUpInside)
        parent.addArrangedSubview(toggle_button)
    }

    private func setup_log_viewer(_ parent: UIStackView) {
        let header_row = UIStackView()
        header_row.axis = .horizontal

        let log_title = UILabel()
        log_title.text = "Live Audit & Tool Logs"
        log_title.font = UIFont.boldSystemFont(ofSize: 14)
        log_title.textColor = MPTheme.text_secondary
        header_row.addArrangedSubview(log_title)

        let clear_btn = UIButton(type: .system)
        clear_btn.setTitle("Clear", for: .normal)
        clear_btn.setTitleColor(MPTheme.primary_accent, for: .normal)
        clear_btn.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        clear_btn.addTarget(self, action: #selector(clear_logs), for: .touchUpInside)
        header_row.addArrangedSubview(clear_btn)

        parent.addArrangedSubview(header_row)

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

    private func setup_tools_preview(_ parent: UIStackView) {
        let tools_title = UILabel()
        tools_title.text = "Registered MCP Tools (\(McpToolRegistry.shared.list_tools().count))"
        tools_title.font = UIFont.boldSystemFont(ofSize: 14)
        tools_title.textColor = MPTheme.text_secondary
        parent.addArrangedSubview(tools_title)

        for t in McpToolRegistry.shared.list_tools() {
            let name = t["name"] as? String ?? ""
            let desc = t["description"] as? String ?? ""

            let row = UIStackView()
            row.axis = .vertical
            row.spacing = 2
            row.backgroundColor = MPTheme.surface_dark
            row.isLayoutMarginsRelativeArrangement = true
            row.layoutMargins = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
            row.layer.cornerRadius = 6

            let name_lbl = UILabel()
            name_lbl.text = name
            name_lbl.textColor = MPTheme.secondary_accent
            name_lbl.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .bold)
            row.addArrangedSubview(name_lbl)

            let desc_lbl = UILabel()
            desc_lbl.text = desc
            desc_lbl.textColor = MPTheme.text_secondary
            desc_lbl.font = UIFont.systemFont(ofSize: 11)
            desc_lbl.numberOfLines = 0
            row.addArrangedSubview(desc_lbl)

            parent.addArrangedSubview(row)
        }
    }

    private func bind_server_logs() {
        McpServer.shared.on_log_message = { [weak self] msg in
            guard let self = self else { return }
            self.logs.append(msg)
            if self.logs.count > 200 { self.logs.removeFirst() }
            self.log_view.text = self.logs.joined(separator: "\n")
            if !self.logs.isEmpty {
                let range = NSRange(location: self.log_view.text.count - 1, length: 1)
                self.log_view.scrollRangeToVisible(range)
            }
        }
    }

    private func update_state() {
        let running = McpServer.shared.is_running
        status_badge.backgroundColor = running ? UIColor.systemGreen : UIColor.systemGray
        status_label.text = running ? "MCP Server: Active (Listening)" : "MCP Server: Inactive"

        let ip = McpServer.shared.get_wifi_address() ?? "127.0.0.1"
        let endpoint = "http://\(ip):\(McpServer.shared.port)/mcp"
        url_label.text = running ? endpoint : "Server stopped (Will listen on \(ip):\(McpServer.shared.port))"

        toggle_button.setTitle(running ? "Stop MCP Service" : "Start MCP Service", for: .normal)
        toggle_button.backgroundColor = running ? UIColor.systemRed : MPTheme.primary_accent
        toggle_button.setTitleColor(.white, for: .normal)
        port_field.isEnabled = !running
    }

    @objc private func toggle_server() {
        if McpServer.shared.is_running {
            McpServer.shared.stop()
        } else {
            let port_str = port_field.text ?? "8787"
            let port = UInt16(port_str) ?? 8787
            do {
                try McpServer.shared.start(port: port)
            } catch {
                let alert = UIAlertController(title: "Startup Error", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }
        update_state()
    }

    @objc private func copy_url() {
        let ip = McpServer.shared.get_wifi_address() ?? "127.0.0.1"
        let url = "http://\(ip):\(McpServer.shared.port)/mcp"
        UIPasteboard.general.string = url

        let alert = UIAlertController(title: "Copied", message: url, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func clear_logs() {
        logs.removeAll()
        log_view.text = ""
    }

    @objc private func show_claude_config() {
        let ip = McpServer.shared.get_wifi_address() ?? "127.0.0.1"
        let port = McpServer.shared.port
        let json_snippet = """
{
  "mcpServers": {
    "mp-manager": {
      "url": "http://\(ip):\(port)/mcp"
    }
  }
}
"""
        let alert = UIAlertController(title: "Agent Configuration", message: "Add to claude_desktop_config.json or Cursor/Antigravity settings:", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Copy JSON", style: .default, handler: { _ in
            UIPasteboard.general.string = json_snippet
        }))
        alert.addAction(UIAlertAction(title: "Close", style: .cancel))
        present(alert, animated: true)
    }
}
