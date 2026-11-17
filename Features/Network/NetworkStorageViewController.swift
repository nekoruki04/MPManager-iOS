import UIKit

public final class NetworkStorageViewController: UIViewController {
    private let table_view = UITableView()
    private var connections: [NetworkStorageItem] = []
    private let defaults_key = "mp_network_connections_v1"

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "Network Connections"
        view.backgroundColor = MPTheme.surface_dark

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(handle_add))

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

        load_connections()
    }

    private func load_connections() {
        if let data = UserDefaults.standard.data(forKey: defaults_key),
           let list = try? JSONDecoder().decode([NetworkStorageItem].self, from: data) {
            connections = list
        } else {
            connections = [
                NetworkStorageItem(name: "Demo FTP", proto: .ftp, host: "ftp.dlptest.com", port: 21, path: "/", username: "dlpuser")
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

    @objc private func handle_add() {
        let alert = UIAlertController(title: "Add Connection", message: "Enter server details:", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Profile Name (e.g. My SFTP)" }
        alert.addTextField { $0.placeholder = "Host (e.g. 192.168.1.50)" }
        alert.addTextField { $0.placeholder = "Port (e.g. 21, 22, 80)" }
        alert.addTextField { $0.placeholder = "Username" }
        alert.addTextField { $0.placeholder = "Password"; $0.isSecureTextEntry = true }

        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { [weak self] _ in
            guard let self = self,
                  let name = alert.textFields?[0].text, !name.isEmpty,
                  let host = alert.textFields?[1].text, !host.isEmpty else { return }
            let port_str = alert.textFields?[2].text ?? ""
            let port = Int(port_str) ?? 21
            let user = alert.textFields?[3].text ?? ""
            let pass = alert.textFields?[4].text ?? ""

            let item = NetworkStorageItem(name: name, proto: .sftp, host: host, port: port, path: "/", username: user)
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "NetCell", for: indexPath)
        cell.backgroundColor = .clear
        let item = connections[indexPath.row]
        cell.textLabel?.textColor = MPTheme.text_primary
        cell.textLabel?.text = "\(item.name) [\(item.proto.rawValue)]"
        cell.detailTextLabel?.textColor = MPTheme.text_secondary
        cell.detailTextLabel?.text = "\(item.host):\(item.port)"
        cell.imageView?.image = UIImage(systemName: "network")?.withTintColor(MPTheme.primary_accent, renderingMode: .alwaysOriginal)
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = connections[indexPath.row]
        let pass_data = KeychainHelper.get_password(service: "io.github.abdurazaaqmohammed.mpmanager.network", account: item.id.uuidString)
        let pass = pass_data.flatMap { String(data: $0, encoding: .utf8) }

        Task {
            do {
                let files = try await NetworkStorageClient.shared.list_directory(item: item, path: item.path, password: pass)
                await MainActor.run {
                    let alert = UIAlertController(title: item.name, message: "Connected successfully! Found \(files.count) items.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            } catch {
                await MainActor.run {
                    let alert = UIAlertController(title: "Connection Failed", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
}
