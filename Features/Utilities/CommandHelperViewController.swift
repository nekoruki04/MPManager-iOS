import UIKit

public struct CommandTemplate: Sendable {
    public let name: String
    public let command: String
}

public final class CommandHelperViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    private let target_item: FileItem?

    private let table_view = UITableView(frame: .zero, style: .insetGrouped)
    private var presets: [CommandTemplate] = [
        CommandTemplate(name: "Make Executable (chmod +x)", command: "chmod +x \"$FILE\""),
        CommandTemplate(name: "Set Permissions 755", command: "chmod 755 \"$FILE\""),
        CommandTemplate(name: "Pseudo-sign Mach-O (ldid -S)", command: "ldid -S \"$FILE\""),
        CommandTemplate(name: "Inspect File Type", command: "file \"$FILE\""),
        CommandTemplate(name: "List Dynamic Libraries (otool -L)", command: "otool -L \"$FILE\""),
        CommandTemplate(name: "Extract Deb Package (dpkg-deb -x)", command: "dpkg-deb -x \"$FILE\" \"$DIR/extracted\""),
        CommandTemplate(name: "Build Deb Package (dpkg-deb -b)", command: "dpkg-deb -b \"$FILE\" \"$DIR/output.deb\""),
        CommandTemplate(name: "List Tar Archive Entries", command: "tar -ztvf \"$FILE\"")
    ]

    public init(target_item: FileItem? = nil) {
        self.target_item = target_item
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setup_ui()
    }

    private func setup_ui() {
        view.backgroundColor = MPTheme.background_dark
        title = "Command Helper"

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(handle_close))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(add_custom_template))

        table_view.translatesAutoresizingMaskIntoConstraints = false
        table_view.backgroundColor = .clear
        table_view.separatorColor = MPTheme.border_color
        table_view.delegate = self
        table_view.dataSource = self
        table_view.register(UITableViewCell.self, forCellReuseIdentifier: "CmdCell")
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

    @objc private func add_custom_template() {
        let alert = UIAlertController(title: "New Command Template", message: "Use $FILE, $DIR, $NAME as placeholders", preferredStyle: .alert)
        alert.addTextField { tf in tf.placeholder = "Template Name" }
        alert.addTextField { tf in tf.placeholder = "Command (e.g. gzip -d \"$FILE\")" }

        alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { [weak self] _ in
            guard let name = alert.textFields?[0].text, !name.isEmpty,
                  let cmd = alert.textFields?[1].text, !cmd.isEmpty else { return }
            self?.presets.append(CommandTemplate(name: name, command: cmd))
            self?.table_view.reloadData()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return presets.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "CmdCell")
        cell.backgroundColor = MPTheme.surface_dark
        let item = presets[indexPath.row]
        cell.textLabel?.text = item.name
        cell.textLabel?.textColor = MPTheme.text_primary
        cell.textLabel?.font = .systemFont(ofSize: 14, weight: .semibold)

        let preview = expand_template(item.command)
        cell.detailTextLabel?.text = preview
        cell.detailTextLabel?.textColor = MPTheme.text_secondary
        cell.detailTextLabel?.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = presets[indexPath.row]
        let expanded = expand_template(item.command)

        let runner = ShellRunnerViewController(command: expanded)
        navigationController?.pushViewController(runner, animated: true)
    }

    private func expand_template(_ raw: String) -> String {
        guard let item = target_item else {
            return raw
        }
        let dir = (item.path as NSString).deletingLastPathComponent
        return raw.replacingOccurrences(of: "$FILE", with: item.path)
                  .replacingOccurrences(of: "$DIR", with: dir)
                  .replacingOccurrences(of: "$NAME", with: item.name)
    }
}
