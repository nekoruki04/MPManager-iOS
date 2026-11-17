import UIKit

public final class NetworkStorageViewController: UIViewController {
    private let table_view = UITableView()
    private var connections: [NetworkStorageItem] = []
    private let defaults_key = "mp_network_connections_v1"

    public var on_select_remote_session: ((NetworkStorageItem, String?) -> Void)?

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "Network Connections"
        view.backgroundColor = MPTheme.background_dark

        setup_navigation()
        setup_ui()
        load_connections()
    }

    private func setup_navigation() {
        let add_btn = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(handle_add))
        let ftp_srv_btn = UIBarButtonItem(title: "FTP Server", style: .plain, target: self, action: #selector(open_ftp_server))
        navigationItem.rightBarButtonItems = [add_btn, ftp_srv_btn]
    }

    private func setup_ui() {
        table_view.translatesAutoresizingMaskIntoConstraints = false
        table_view.backgroundColor = .clear
        table_view.separatorColor = MPTheme.border_color
        table_view.delegate = self
        table_view.dataSource = self
        table_view.register(UITableViewCell.self, forCellReuseIdentifier: "NetCell")
        view.addSubview(table_view)

        NSLayoutConstraint.activate([
            table_view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            table_view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table_view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table_view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func load_connections() {
        if let data = UserDefaults.standard.data(forKey: defaults_key),
           let list = try? JSONDecoder().decode([NetworkStorageItem].self, from: data) {
            connections = list
        } else {
            connections = [
                NetworkStorageItem(name: "Demo WebDAV", proto: .webdav, host: "demo.owncloud.com", port: 443, path: "/remote.php/webdav", username: "demo"),
                NetworkStorageItem(name: "Local NAS (SFTP)", proto: .sftp, host: "192.168.1.100", port: 22, path: "/home", username: "root")
            ]
            save_connections()
        }
        table_view.reloadData()
    }

    private func save_connections() {
        if let data = try? JSONEncoder().encode(connections) {
            UserDefaults.standard.set(data, forKey: defaults_key)
        }
    }

    @objc private func open_ftp_server() {
        let srv_vc = FtpServerViewController()
        navigationController?.pushViewController(srv_vc, animated: true)
    }

    @objc private func handle_add() {
        let alert = UIAlertController(title: "Add Network Connection", message: "Choose protocol and enter details:", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Profile Name (e.g. My Nextcloud)" }
        alert.addTextField { $0.placeholder = "Protocol: ftp, ftps, sftp, webdav, smb"; $0.text = "webdav" }
        alert.addTextField { $0.placeholder = "Host / Domain (e.g. 192.168.1.50)" }
        alert.addTextField { $0.placeholder = "Port (21, 22, 80, 443, 445)"; $0.text = "443" }
        alert.addTextField { $0.placeholder = "Remote Root Path"; $0.text = "/" }
        alert.addTextField { $0.placeholder = "Username" }
        alert.addTextField { $0.placeholder = "Password"; $0.isSecureTextEntry = true }

        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { [weak self] _ in
            guard let self = self,
                  let name = alert.textFields?[0].text, !name.isEmpty,
                  let proto_str = alert.textFields?[1].text?.lowercased(),
                  let host = alert.textFields?[2].text, !host.isEmpty else { return }

            let proto: NetworkProtocol
            switch proto_str {
            case "ftp": proto = .ftp
            case "ftps": proto = .ftps
            case "sftp": proto = .sftp
            case "webdav": proto = .webdav
            case "smb": proto = .smb
            default: proto = .webdav
            }

            let port_str = alert.textFields?[3].text ?? ""
            let port = Int(port_str) ?? (proto == .sftp ? 22 : (proto == .webdav ? 443 : 21))
            let path = alert.textFields?[4].text ?? "/"
            let user = alert.textFields?[5].text ?? ""
            let pass = alert.textFields?[6].text ?? ""

            let item = NetworkStorageItem(name: name, proto: proto, host: host, port: port, path: path, username: user)
            if !pass.isEmpty {
                _ = KeychainHelper.save_password(service: "io.github.abdurazaaqmohammed.mpmanager.network", account: item.id.uuidString, data: pass.data(using: .utf8)!)
            }
            self.connections.append(item)
            self.save_connections()
            self.table_view.reloadData()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

extension NetworkStorageViewController: UITableViewDataSource, UITableViewDelegate {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return connections.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "NetCell")
        cell.backgroundColor = .clear
        let item = connections[indexPath.row]
        cell.textLabel?.textColor = MPTheme.text_primary
        cell.textLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        cell.textLabel?.text = "\(item.name) [\(item.proto.rawValue.uppercased())]"

        cell.detailTextLabel?.textColor = MPTheme.text_secondary
        cell.detailTextLabel?.text = "\(item.username.isEmpty ? "" : (item.username + "@"))\(item.host):\(item.port)\(item.path)"

        let icon_name: String
        switch item.proto {
        case .webdav: icon_name = "cloud.fill"
        case .sftp: icon_name = "terminal.fill"
        case .ftp, .ftps: icon_name = "arrow.up.arrow.down.circle.fill"
        case .smb: icon_name = "server.rack"
        }
        cell.imageView?.image = UIImage(systemName: icon_name)?.withTintColor(MPTheme.primary_accent, renderingMode: .alwaysOriginal)
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = connections[indexPath.row]
        let pass_data = KeychainHelper.get_password(service: "io.github.abdurazaaqmohammed.mpmanager.network", account: item.id.uuidString)
        let pass = pass_data.flatMap { String(data: $0, encoding: .utf8) }

        let remote_vc = RemoteFilesViewController(connection: item, password: pass)
        navigationController?.pushViewController(remote_vc, animated: true)
    }

    public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let item = connections[indexPath.row]
            _ = KeychainHelper.delete_password(service: "io.github.abdurazaaqmohammed.mpmanager.network", account: item.id.uuidString)
            connections.remove(at: indexPath.row)
            save_connections()
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
}
