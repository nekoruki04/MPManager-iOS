import UIKit

public final class SearchDialogViewController: UIViewController {
    private let root_path: String
    public var on_select_file: ((FileItem) -> Void)?

    private let search_field = UITextField()
    private let content_field = UITextField()
    private let case_switch = UISwitch()
    private let regex_switch = UISwitch()
    private let results_table = UITableView()
    private var results: [FileItem] = []
    private let spinner = UIActivityIndicatorView(style: .medium)

    public init(root_path: String) {
        self.root_path = root_path
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "Search Files"
        view.backgroundColor = MPTheme.surface_dark

        setup_ui()
    }

    private func setup_ui() {
        let form_stack = UIStackView()
        form_stack.translatesAutoresizingMaskIntoConstraints = false
        form_stack.axis = .vertical
        form_stack.spacing = 10
        view.addSubview(form_stack)

        configure_field(search_field, placeholder: "Search filename (e.g. *.dex, main)")
        form_stack.addArrangedSubview(search_field)

        configure_field(content_field, placeholder: "Containing text (optional)")
        form_stack.addArrangedSubview(content_field)

        let toggles_row = UIStackView()
        toggles_row.axis = .horizontal
        toggles_row.spacing = 16

        let case_label = UILabel()
        case_label.text = "Match Case"
        case_label.textColor = MPTheme.text_secondary
        case_label.font = UIFont.systemFont(ofSize: 13)
        toggles_row.addArrangedSubview(case_label)
        toggles_row.addArrangedSubview(case_switch)

        let regex_label = UILabel()
        regex_label.text = "Regex"
        regex_label.textColor = MPTheme.text_secondary
        regex_label.font = UIFont.systemFont(ofSize: 13)
        toggles_row.addArrangedSubview(regex_label)
        toggles_row.addArrangedSubview(regex_switch)

        form_stack.addArrangedSubview(toggles_row)

        let search_btn = UIButton(type: .system)
        search_btn.setTitle("Start Search", for: .normal)
        search_btn.backgroundColor = MPTheme.primary_accent
        search_btn.setTitleColor(.white, for: .normal)
        search_btn.layer.cornerRadius = 8
        search_btn.heightAnchor.constraint(equalToConstant: 40).isActive = true
        search_btn.addTarget(self, action: #selector(perform_search), for: .touchUpInside)
        form_stack.addArrangedSubview(search_btn)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        spinner.color = MPTheme.primary_accent
        view.addSubview(spinner)

        results_table.translatesAutoresizingMaskIntoConstraints = false
        results_table.backgroundColor = MPTheme.background_dark
        results_table.separatorColor = MPTheme.border_color
        results_table.delegate = self
        results_table.dataSource = self
        results_table.register(FileCell.self, forCellReuseIdentifier: FileCell.reuse_id)
        view.addSubview(results_table)

        NSLayoutConstraint.activate([
            form_stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            form_stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            form_stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: form_stack.bottomAnchor, constant: 8),

            results_table.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 8),
            results_table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            results_table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            results_table.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configure_field(_ field: UITextField, placeholder: String) {
        field.placeholder = placeholder
        field.backgroundColor = MPTheme.background_dark
        field.textColor = MPTheme.text_primary
        field.layer.cornerRadius = 6
        field.layer.borderColor = MPTheme.border_color.cgColor
        field.layer.borderWidth = 1
        field.heightAnchor.constraint(equalToConstant: 38).isActive = true
        let pad = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 38))
        field.leftView = pad
        field.leftViewMode = .always
    }

    @objc private func perform_search() {
        search_field.resignFirstResponder()
        content_field.resignFirstResponder()
        spinner.startAnimating()

        let query = SearchQuery(
            root_path: root_path,
            name_query: search_field.text ?? "",
            match_case: case_switch.isOn,
            is_regex: regex_switch.isOn,
            content_query: content_field.text
        )

        Task {
            let matches = await FileSearchEngine.shared.execute_search(query: query)
            await MainActor.run {
                self.spinner.stopAnimating()
                self.results = matches
                self.results_table.reloadData()
            }
        }
    }
}

extension SearchDialogViewController: UITableViewDataSource, UITableViewDelegate {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: FileCell.reuse_id, for: indexPath) as? FileCell else {
            return UITableViewCell()
        }
        let item = results[indexPath.row]
        cell.configure(with: item, is_selected: false)
        return cell
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 56
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = results[indexPath.row]
        dismiss(animated: true) { [weak self] in
            self?.on_select_file?(item)
        }
    }
}
