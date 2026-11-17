import UIKit

public final class BatchRenameViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    public var on_completed: (() -> Void)?

    private let items: [FileItem]
    private var renamed_pairs: [(original: FileItem, new_name: String)] = []

    private let mode_segment = UISegmentedControl(items: ["Template (Prefix/Index)", "Find & Replace"])
    private let stack_view = UIStackView()

    private let prefix_field = UITextField()
    private let suffix_field = UITextField()
    private let start_index_field = UITextField()
    private let digits_field = UITextField()

    private let find_field = UITextField()
    private let replace_field = UITextField()

    private let table_view = UITableView()

    public init(items: [FileItem]) {
        self.items = items
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setup_ui()
        update_preview()
    }

    private func setup_ui() {
        view.backgroundColor = MPTheme.background_dark
        title = "Batch Rename (\(items.count) files)"

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(handle_cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Apply", style: .done, target: self, action: #selector(handle_apply))

        mode_segment.translatesAutoresizingMaskIntoConstraints = false
        mode_segment.selectedSegmentIndex = 0
        mode_segment.selectedSegmentTintColor = MPTheme.primary_accent
        mode_segment.addTarget(self, action: #selector(mode_changed), for: .valueChanged)
        view.addSubview(mode_segment)

        stack_view.translatesAutoresizingMaskIntoConstraints = false
        stack_view.axis = .vertical
        stack_view.spacing = 8
        view.addSubview(stack_view)

        setup_text_field(prefix_field, placeholder: "Prefix (e.g. photo_)")
        setup_text_field(suffix_field, placeholder: "Suffix (e.g. _backup)")
        setup_text_field(start_index_field, placeholder: "Start index (default 1)")
        start_index_field.keyboardType = .numberPad
        setup_text_field(digits_field, placeholder: "Digits padding (e.g. 2 for 01, 02)")
        digits_field.keyboardType = .numberPad

        setup_text_field(find_field, placeholder: "Find text...")
        setup_text_field(replace_field, placeholder: "Replace with...")

        stack_view.addArrangedSubview(prefix_field)
        stack_view.addArrangedSubview(suffix_field)
        stack_view.addArrangedSubview(start_index_field)
        stack_view.addArrangedSubview(digits_field)

        table_view.translatesAutoresizingMaskIntoConstraints = false
        table_view.backgroundColor = .clear
        table_view.separatorColor = MPTheme.border_color
        table_view.delegate = self
        table_view.dataSource = self
        table_view.register(UITableViewCell.self, forCellReuseIdentifier: "PreviewCell")
        view.addSubview(table_view)

        NSLayoutConstraint.activate([
            mode_segment.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            mode_segment.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            mode_segment.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            stack_view.topAnchor.constraint(equalTo: mode_segment.bottomAnchor, constant: 12),
            stack_view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack_view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            table_view.topAnchor.constraint(equalTo: stack_view.bottomAnchor, constant: 16),
            table_view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table_view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table_view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setup_text_field(_ tf: UITextField, placeholder: String) {
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.backgroundColor = MPTheme.surface_dark
        tf.textColor = MPTheme.text_primary
        tf.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [.foregroundColor: MPTheme.text_secondary])
        tf.borderStyle = .roundedRect
        tf.heightAnchor.constraint(equalToConstant: 38).isActive = true
        tf.delegate = self
        tf.addTarget(self, action: #selector(text_field_did_change), for: .editingChanged)
    }

    @objc private func mode_changed() {
        let is_template = mode_segment.selectedSegmentIndex == 0
        stack_view.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if is_template {
            stack_view.addArrangedSubview(prefix_field)
            stack_view.addArrangedSubview(suffix_field)
            stack_view.addArrangedSubview(start_index_field)
            stack_view.addArrangedSubview(digits_field)
        } else {
            stack_view.addArrangedSubview(find_field)
            stack_view.addArrangedSubview(replace_field)
        }
        update_preview()
    }

    @objc private func text_field_did_change() {
        update_preview()
    }

    private func update_preview() {
        var pairs: [(original: FileItem, new_name: String)] = []
        let is_template = mode_segment.selectedSegmentIndex == 0

        if is_template {
            let prefix = prefix_field.text ?? ""
            let suffix = suffix_field.text ?? ""
            let start_idx = Int(start_index_field.text ?? "") ?? 1
            let padding = Int(digits_field.text ?? "") ?? 0

            for (i, item) in items.enumerated() {
                let idx = start_idx + i
                let idx_str: String
                if padding > 0 {
                    idx_str = String(format: "%0*d", padding, idx)
                } else {
                    idx_str = "\(idx)"
                }
                let ext = (item.name as NSString).pathExtension
                let base = (item.name as NSString).deletingPathExtension

                var new_base = base
                if !prefix.isEmpty || !suffix.isEmpty || !start_index_field.text!.isEmpty {
                    new_base = "\(prefix)\(idx_str)\(suffix)"
                }
                let full_new_name = ext.isEmpty ? new_base : "\(new_base).\(ext)"
                pairs.append((original: item, new_name: full_new_name))
            }
        } else {
            let find = find_field.text ?? ""
            let replace = replace_field.text ?? ""

            for item in items {
                var new_name = item.name
                if !find.isEmpty {
                    new_name = new_name.replacingOccurrences(of: find, with: replace)
                }
                pairs.append((original: item, new_name: new_name))
            }
        }

        self.renamed_pairs = pairs
        table_view.reloadData()
    }

    @objc private func handle_cancel() {
        dismiss(animated: true)
    }

    @objc private func handle_apply() {
        let pairs_to_rename = renamed_pairs.filter { $0.original.name != $0.new_name }
        guard !pairs_to_rename.isEmpty else {
            dismiss(animated: true)
            return
        }

        let alert = UIAlertController(title: "Batch Rename", message: "Rename \(pairs_to_rename.count) files now?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Rename", style: .destructive, handler: { [weak self] _ in
            self?.execute_rename(pairs: pairs_to_rename)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func execute_rename(pairs: [(original: FileItem, new_name: String)]) {
        Task {
            var errors: [String] = []
            for pair in pairs {
                do {
                    try FileOperationsQueue.shared.rename_item(at: pair.original.path, to: pair.new_name)
                } catch {
                    errors.append("\(pair.original.name): \(error.localizedDescription)")
                }
            }

            await MainActor.run {
                if !errors.isEmpty {
                    let err_alert = UIAlertController(title: "Errors Occurred", message: errors.joined(separator: "\n"), preferredStyle: .alert)
                    err_alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
                        self?.dismiss(animated: true) { self?.on_completed?() }
                    }))
                    self.present(err_alert, animated: true)
                } else {
                    self.dismiss(animated: true) { self.on_completed?() }
                }
            }
        }
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return renamed_pairs.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "PreviewCell")
        cell.backgroundColor = .clear
        let pair = renamed_pairs[indexPath.row]
        let is_modified = pair.original.name != pair.new_name

        cell.textLabel?.text = pair.original.name
        cell.textLabel?.textColor = is_modified ? MPTheme.text_secondary : MPTheme.text_primary
        cell.textLabel?.font = .systemFont(ofSize: 14)

        cell.detailTextLabel?.text = "➔ \(pair.new_name)"
        cell.detailTextLabel?.textColor = is_modified ? MPTheme.primary_accent : MPTheme.text_secondary
        cell.detailTextLabel?.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        return cell
    }
}
