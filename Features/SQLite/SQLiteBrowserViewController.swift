import UIKit
import SQLite3

public final class SQLiteBrowserViewController: UIViewController {
    private let db_path: String
    private var db: OpaquePointer?
    private var tables: [String] = []
    private var current_table: String?

    private let table_picker = UISegmentedControl()
    private let text_view = UITextView()

    public init(db_path: String) {
        self.db_path = db_path
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let d = db { sqlite3_close(d) }
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = (db_path as NSString).lastPathComponent
        view.backgroundColor = MPTheme.background_dark

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Query", style: .plain, target: self, action: #selector(handle_query))

        table_picker.translatesAutoresizingMaskIntoConstraints = false
        table_picker.backgroundColor = MPTheme.surface_dark
        table_picker.selectedSegmentTintColor = MPTheme.primary_accent
        table_picker.addTarget(self, action: #selector(table_changed), for: .valueChanged)
        view.addSubview(table_picker)

        text_view.translatesAutoresizingMaskIntoConstraints = false
        text_view.backgroundColor = MPTheme.background_dark
        text_view.textColor = MPTheme.text_primary
        text_view.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        text_view.isEditable = false
        view.addSubview(text_view)

        NSLayoutConstraint.activate([
            table_picker.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            table_picker.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            table_picker.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),

            text_view.topAnchor.constraint(equalTo: table_picker.bottomAnchor, constant: 8),
            text_view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            text_view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            text_view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        open_database()
    }

    private func open_database() {
        if sqlite3_open_v2(db_path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            text_view.text = "Failed to open SQLite database."
            return
        }

        tables = query_tables()
        table_picker.removeAllSegments()
        for (i, t) in tables.prefix(8).enumerated() {
            table_picker.insertSegment(withTitle: t, at: i, animated: false)
        }
        if !tables.isEmpty {
            table_picker.selectedSegmentIndex = 0
            current_table = tables[0]
            load_table_data(tables[0])
        } else {
            text_view.text = "Database contains no tables."
        }
    }

    private func query_tables() -> [String] {
        var list: [String] = []
        var stmt: OpaquePointer?
        let sql = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let c_str = sqlite3_column_text(stmt, 0) {
                    list.append(String(cString: c_str))
                }
            }
        }
        sqlite3_finalize(stmt)
        return list
    }

    @objc private func table_changed() {
        let idx = table_picker.selectedSegmentIndex
        guard idx >= 0 && idx < tables.count else { return }
        current_table = tables[idx]
        load_table_data(tables[idx])
    }

    private func load_table_data(_ table_name: String) {
        let sql = "SELECT * FROM \"\(table_name)\" LIMIT 100;"
        execute_and_display(sql: sql)
    }

    private func execute_and_display(sql: String) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let err_msg = sqlite3_errmsg(db).map { String(cString: $0) } ?? "Syntax error"
            text_view.text = "Error: \(err_msg)"
            return
        }
        defer { sqlite3_finalize(stmt) }

        let col_count = sqlite3_column_count(stmt)
        var headers: [String] = []
        for i in 0..<col_count {
            let name = sqlite3_column_name(stmt, i).map { String(cString: $0) } ?? "Col\(i)"
            headers.append(name)
        }

        var output = headers.joined(separator: " | ") + "\n"
        output += String(repeating: "-", count: max(40, output.count)) + "\n"

        var rows = 0
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows += 1
            var row_vals: [String] = []
            for i in 0..<col_count {
                if let text = sqlite3_column_text(stmt, i) {
                    row_vals.append(String(cString: text))
                } else {
                    row_vals.append("NULL")
                }
            }
            output += row_vals.joined(separator: " | ") + "\n"
        }

        output += "\n[Total rows displayed: \(rows)]"
        text_view.text = output
    }

    @objc private func handle_query() {
        let alert = UIAlertController(title: "Execute SQL", message: "Enter custom SELECT query:", preferredStyle: .alert)
        alert.addTextField { $0.text = "SELECT * FROM \"\(self.current_table ?? "")\" LIMIT 50;" }
        alert.addAction(UIAlertAction(title: "Run", style: .default, handler: { [weak self] _ in
            guard let q = alert.textFields?.first?.text else { return }
            self?.execute_and_display(sql: q)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}
