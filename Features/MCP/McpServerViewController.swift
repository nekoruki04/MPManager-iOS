import UIKit

public final class McpServerViewController: UIViewController {
    private let status_label = UILabel()
    private let url_label = UILabel()
    private let toggle_button = UIButton(type: .system)

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "MCP Service"
        view.backgroundColor = MPTheme.surface_dark

        setup_ui()
        update_state()
    }

    private func setup_ui() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        let title_label = UILabel()
        title_label.text = "Model Context Protocol Server"
        title_label.font = UIFont.boldSystemFont(ofSize: 18)
        title_label.textColor = MPTheme.text_primary
        stack.addArrangedSubview(title_label)

        let desc_label = UILabel()
        desc_label.text = "Allows external AI assistants to browse files, inspect APKs, and manage archives through local MCP protocol."
        desc_label.font = UIFont.systemFont(ofSize: 13)
        desc_label.textColor = MPTheme.text_secondary
        desc_label.numberOfLines = 0
        stack.addArrangedSubview(desc_label)

        status_label.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        stack.addArrangedSubview(status_label)

        url_label.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        url_label.textColor = MPTheme.primary_accent
        stack.addArrangedSubview(url_label)

        toggle_button.setTitleColor(.white, for: .normal)
        toggle_button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 15)
        toggle_button.layer.cornerRadius = 8
        toggle_button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        toggle_button.addTarget(self, action: #selector(toggle_server), for: .touchUpInside)
        stack.addArrangedSubview(toggle_button)

        let tools_title = UILabel()
        tools_title.text = "Available Tools:"
        tools_title.font = UIFont.boldSystemFont(ofSize: 15)
        tools_title.textColor = MPTheme.text_primary
        stack.addArrangedSubview(tools_title)

        let tools = [
            "mp_file_list: Directory listing with permissions",
            "mp_file_read: Read text content of any file",
            "mp_file_write: Write/overwrite file contents",
            "mp_file_delete: Safe recursive deletion",
            "mp_zip_list: View archive contents without extraction",
            "mp_zip_extract: Unpack archive to target folder",
            "mp_apk_info: Parse manifest, signatures, and DEX"
        ]

        for t in tools {
            let l = UILabel()
            l.text = "• " + t
            l.font = UIFont.systemFont(ofSize: 12)
            l.textColor = MPTheme.text_secondary
            l.numberOfLines = 0
            stack.addArrangedSubview(l)
        }
    }

    private func update_state() {
        let running = McpServer.shared.is_running
        status_label.text = running ? "Status: Active (Listening)" : "Status: Inactive"
        status_label.textColor = running ? MPTheme.secondary_accent : MPTheme.text_secondary
        url_label.text = running ? "http://127.0.0.1:8787/mcp" : "Server not running"

        toggle_button.setTitle(running ? "Stop MCP Service" : "Start MCP Service", for: .normal)
        toggle_button.backgroundColor = running ? UIColor.systemRed : MPTheme.primary_accent
    }

    @objc private func toggle_server() {
        if McpServer.shared.is_running {
            McpServer.shared.stop()
        } else {
            do {
                try McpServer.shared.start()
            } catch {
                let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }
        update_state()
    }
}
