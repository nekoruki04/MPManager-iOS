import UIKit

public protocol MainFilesPaneDelegate: AnyObject, Sendable {
    func pane_did_request_open_file(item: FileItem, from pane_id: Int)
    func pane_did_change_path(path: String, item_count: Int, from pane_id: Int)
    func pane_did_request_context_menu(items: [FileItem], from pane_id: Int)
    func pane_did_gain_focus(pane_id: Int)
}

public final class MainFilesViewController: UIViewController {
    public let pane_id: Int
    public private(set) var current_path: String
    public weak var delegate: (any MainFilesPaneDelegate)?

    public var is_active: Bool = false {
        didSet {
            highlight_view.is_active = is_active
        }
    }

    private let table_view = UITableView()
    private let refresh_control = UIRefreshControl()
    private let highlight_view = PaneHighlightView()

    private var items: [FileItem] = []
    private var selected_items: Set<String> = []
    private var back_stack: [String] = []
    private var forward_stack: [String] = []

    public init(pane_id: Int, initial_path: String) {
        self.pane_id = pane_id
        self.current_path = initial_path
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setup_ui()
        navigate_to(path: current_path, record_history: false)
    }

    private func setup_ui() {
        view.backgroundColor = MPTheme.background_dark

        table_view.translatesAutoresizingMaskIntoConstraints = false
        table_view.backgroundColor = .clear
        table_view.separatorColor = MPTheme.border_color
        table_view.delegate = self
        table_view.dataSource = self
        table_view.register(FileCell.self, forCellReuseIdentifier: FileCell.reuse_id)

        refresh_control.tintColor = MPTheme.primary_accent
        refresh_control.addTarget(self, action: #selector(handle_refresh), for: .valueChanged)
        table_view.refreshControl = refresh_control
        view.addSubview(table_view)

        highlight_view.translatesAutoresizingMaskIntoConstraints = false
        highlight_view.active_color = (pane_id == 1) ? MPTheme.primary_accent : MPTheme.secondary_accent
        view.addSubview(highlight_view)

        let tap_gesture = UITapGestureRecognizer(target: self, action: #selector(handle_pane_tap))
        tap_gesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tap_gesture)

        let long_press = UILongPressGestureRecognizer(target: self, action: #selector(handle_long_press(_:)))
        table_view.addGestureRecognizer(long_press)

        NSLayoutConstraint.activate([
            table_view.topAnchor.constraint(equalTo: view.topAnchor),
            table_view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table_view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table_view.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            highlight_view.topAnchor.constraint(equalTo: view.topAnchor),
            highlight_view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            highlight_view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            highlight_view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    public func navigate_to(path: String, record_history: Bool = true) {
        if record_history && path != current_path {
            back_stack.append(current_path)
            forward_stack.removeAll()
        }
        current_path = path
        BookmarkStore.shared.add_history(path: path, pane: pane_id)
        selected_items.removeAll()
        load_directory()
    }

    public func navigate_back() {
        guard let prev = back_stack.popLast() else { return }
        forward_stack.append(current_path)
        current_path = prev
        selected_items.removeAll()
        load_directory()
    }

    public func navigate_forward() {
        guard let next = forward_stack.popLast() else { return }
        back_stack.append(current_path)
        current_path = next
        selected_items.removeAll()
        load_directory()
    }

    public func navigate_up() {
        let parent = (current_path as NSString).deletingLastPathComponent
        if !parent.isEmpty && parent != current_path {
            navigate_to(path: parent)
        }
    }

    public func reload() {
        load_directory()
    }

    public var current_selected_items: [FileItem] {
        items.filter { selected_items.contains($0.path) }
    }

    public func clear_selection() {
        selected_items.removeAll()
        table_view.reloadData()
    }

    @objc private func handle_refresh() {
        load_directory()
    }

    @objc private func handle_pane_tap() {
        delegate?.pane_did_gain_focus(pane_id: pane_id)
    }

    @objc private func handle_long_press(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: table_view)
        if let index_path = table_view.indexPathForRow(at: point) {
            let item = items[index_path.row]
            if !selected_items.contains(item.path) {
                selected_items.insert(item.path)
                table_view.reloadRows(at: [index_path], with: .none)
            }
            delegate?.pane_did_request_context_menu(items: current_selected_items, from: pane_id)
        }
    }

    private func load_directory() {
        Task {
            do {
                let list = try await FileSystemProvider.shared.contents_of_directory(at: current_path)
                await MainActor.run {
                    self.items = list
                    self.refresh_control.endRefreshing()
                    self.table_view.reloadData()
                    self.delegate?.pane_did_change_path(path: self.current_path, item_count: list.count, from: self.pane_id)
                }
            } catch {
                await MainActor.run {
                    self.refresh_control.endRefreshing()
                    let alert = UIAlertController(title: "Access Error", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
}

extension MainFilesViewController: UITableViewDataSource, UITableViewDelegate {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: FileCell.reuse_id, for: indexPath) as? FileCell else {
            return UITableViewCell()
        }
        let item = items[indexPath.row]
        let is_sel = selected_items.contains(item.path)
        cell.configure(with: item, is_selected: is_sel)
        return cell
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 56
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = items[indexPath.row]
        delegate?.pane_did_gain_focus(pane_id: pane_id)

        if !selected_items.isEmpty {
            if selected_items.contains(item.path) {
                selected_items.remove(item.path)
            } else {
                selected_items.insert(item.path)
            }
            tableView.reloadRows(at: [indexPath], with: .none)
            return
        }

        if item.is_directory {
            navigate_to(path: item.path)
        } else {
            delegate?.pane_did_request_open_file(item: item, from: pane_id)
        }
    }
}
