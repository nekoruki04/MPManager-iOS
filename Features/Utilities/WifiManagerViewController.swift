import UIKit
import SystemConfiguration.CaptiveNetwork

public struct NetworkInterfaceInfo: Sendable {
    public let name: String
    public let ipv4: String?
    public let netmask: String?
    public let broadcast: String?
}

public final class WifiManagerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    private let table_view = UITableView(frame: .zero, style: .insetGrouped)
    private var interfaces: [NetworkInterfaceInfo] = []
    private var details: [(title: String, value: String)] = []

    public override func viewDidLoad() {
        super.viewDidLoad()
        setup_ui()
        refresh_network_info()
    }

    private func setup_ui() {
        view.backgroundColor = MPTheme.background_dark
        title = "Wi-Fi & Network Manager"

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(handle_close))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refresh_network_info))

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

    @objc private func handle_close() {
        dismiss(animated: true)
    }

    @objc private func refresh_network_info() {
        interfaces = get_interfaces()
        var list: [(title: String, value: String)] = []

        let wifi = interfaces.first(where: { $0.name == "en0" })
        list.append(("Wi-Fi Interface", wifi?.name ?? "en0 (Inactive)"))
        list.append(("IPv4 Address", wifi?.ipv4 ?? "Not Connected"))
        list.append(("Subnet Mask", wifi?.netmask ?? "Unknown"))
        list.append(("Broadcast Address", wifi?.broadcast ?? "Unknown"))

        let cellular = interfaces.first(where: { $0.name == "pdp_ip0" })
        if let cell = cellular, let ip = cell.ipv4 {
            list.append(("Cellular IP", ip))
        }

        let loopback = interfaces.first(where: { $0.name == "lo0" })
        list.append(("Loopback IP", loopback?.ipv4 ?? "127.0.0.1"))

        self.details = list
        table_view.reloadData()
    }

    private func get_interfaces() -> [NetworkInterfaceInfo] {
        var results: [NetworkInterfaceInfo] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return results }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            let flags = Int32(current.pointee.ifa_flags)
            let addr = current.pointee.ifa_addr.pointee

            if (flags & (IFF_UP | IFF_RUNNING)) != 0 && addr.sa_family == UInt8(AF_INET) {
                let name = String(cString: current.pointee.ifa_name)

                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                var ip: String?
                if getnameinfo(current.pointee.ifa_addr, socklen_t(addr.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                    ip = String(cString: host)
                }

                var netmask: String?
                if let netaddr = current.pointee.ifa_netmask {
                    var mask_buf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(netaddr, socklen_t(netaddr.pointee.sa_len), &mask_buf, socklen_t(mask_buf.count), nil, 0, NI_NUMERICHOST) == 0 {
                        netmask = String(cString: mask_buf)
                    }
                }

                var broad: String?
                if let baddr = current.pointee.ifa_dstaddr {
                    var b_buf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(baddr, socklen_t(baddr.pointee.sa_len), &b_buf, socklen_t(b_buf.count), nil, 0, NI_NUMERICHOST) == 0 {
                        broad = String(cString: b_buf)
                    }
                }

                results.append(NetworkInterfaceInfo(name: name, ipv4: ip, netmask: netmask, broadcast: broad))
            }
            ptr = current.pointee.ifa_next
        }
        return results
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return details.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "NetCell")
        cell.backgroundColor = MPTheme.surface_dark
        let item = details[indexPath.row]
        cell.textLabel?.text = item.title
        cell.textLabel?.textColor = MPTheme.text_primary
        cell.textLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        cell.detailTextLabel?.text = item.value
        cell.detailTextLabel?.textColor = MPTheme.primary_accent
        cell.detailTextLabel?.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = details[indexPath.row]
        UIPasteboard.general.string = item.value
        let alert = UIAlertController(title: "Copied", message: "\(item.title): \(item.value)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
