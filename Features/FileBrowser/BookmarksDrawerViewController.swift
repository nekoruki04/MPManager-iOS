import UIKit

public final class BookmarksDrawerViewController: UIViewController {
    public var on_select_path: ((String) -> Void)?
    private let pane_id: Int
    private let current_path: String

    private let segmented_control = UISegmentedControl(items: ["Bookmarks", "History"])
    private let table_view = UITableView()
    private var bookmarks_list: [BookmarkItem] = []
    private var history_list: [String] = []

    public init(pane_id: Int, current_path: String) {
        self.pane_id = pane_id
        self.current_path = current_path
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = MPTheme.surface_dark

        setup_ui()
        load_data()
    }

    private func setup_ui() {
        let header_stack = UIStackView()
        header_stack.translatesAutoresizingMaskIntoConstraints = false
        header_stack.axis = .horizontal
        header_stack.spacing = 12
        header_stack.alignment = .center

        segmented_control.selectedSegmentIndex = 0
        segmented_control.backgroundColor = MPTheme.background_dark
        segmented_control.selectedSegmentTintColor = MPTheme.primary_accent
        segmented_control.addTarget(self, action: #selector(tab_changed), for: .valueChanged)
        header_stack.addArrangedSubview(segmented_control)

        let add_btn = UIButton(type: .system)
        add_btn.setImage(UIImage(systemName: "plus"), for: .normal)
        add_btn.tintColor = MPTheme.primary_accent
        add_btn.addTarget(self, action: #selector(add_current_bookmark), for: .touchUpInside)
        header_stack.addArrangedSubview(add_btn)

        view.addSubview(header_stack)

        table_view.translatesAutoresizingMaskIntoConstraints = false
        table_view.backgroundColor = .clear
        table_view.separatorColor = MPTheme.border_color
        table_view.delegate = self
        table_view.dataSource = self
        table_view.register(UITableViewCell.self, forCellReuseIdentifier: "DrawerCell")
        view.addSubview(table_view)

        NSLayoutConstraint.activate([
            header_stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            header_stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            header_stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            table_view.topAnchor.constraint(equalTo: header_stack.bottomAnchor, constant: 12),
            table_view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table_view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table_view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func load_data() {
        bookmarks_list = BookmarkStore.shared.bookmarks
        history_list = BookmarkStore.shared.get_history(pane: pane_id)
        table_view.reloadData()
    }

    @objc private func tab_changed() {
        table_view.reloadData()
    }

    @objc private func add_current_bookmark() {
        let name = (current_path as NSString).lastPathComponent
        BookmarkStore.shared.add_bookmark(name: name.isEmpty ? "/" : name, path: current_path)
        load_data()
    }
}

extension BookmarksDrawerViewController: UITableViewDataSource, UITableViewDelegate {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return segmented_control.selectedSegmentIndex == 0 ? bookmarks_list.count : history_list.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DrawerCell", for: indexPath)
        cell.backgroundColor = .clear
        cell.textLabel?.textColor = MPTheme.text_primary
        cell.detailTextLabel?.textColor = MPTheme.text_secondary

        if segmented_control.selectedSegmentIndex == 0 {
            let item = bookmarks_list[indexPath.row]
            cell.textLabel?.text = item.name
            cell.imageView?.image = UIImage(systemName: "bookmark.fill")?.withTintColor(MPTheme.folder_amber, renderingMode: .alwaysOriginal)
        } else {
            let path = history_list[indexPath.row]
            cell.textLabel?.text = path
            cell.imageView?.image = UIImage(systemName: "clock.arrow.circlepath")?.withTintColor(MPTheme.primary_accent, renderingMode: .alwaysOriginal)
        }
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selected_path: String
        if segmented_control.selectedSegmentIndex == 0 {
            selected_path = bookmarks_list[indexPath.row].path
        } else {
            selected_path = history_list[indexPath.row]
        }
        dismiss(animated: true) { [weak self] in
            self?.on_select_path?(selected_path)
        }
    }
}
