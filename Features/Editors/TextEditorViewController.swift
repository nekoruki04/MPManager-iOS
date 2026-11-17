import UIKit

public final class TextEditorViewController: UIViewController {
    private let file_path: String
    private let text_view = UITextView()
    private let line_number_view = UITextView()
    private let search_bar = UISearchBar()
    private var is_search_visible = false

    public init(file_path: String) {
        self.file_path = file_path
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setup_ui()
        load_content()
    }

    private func setup_ui() {
        title = (file_path as NSString).lastPathComponent
        view.backgroundColor = MPTheme.background_dark

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(handle_save)),
            UIBarButtonItem(barButtonSystemItem: .search, target: self, action: #selector(toggle_search))
        ]

        search_bar.translatesAutoresizingMaskIntoConstraints = false
        search_bar.placeholder = "Find in file..."
        search_bar.barStyle = .black
        search_bar.isHidden = true
        search_bar.delegate = self
        view.addSubview(search_bar)

        line_number_view.translatesAutoresizingMaskIntoConstraints = false
        line_number_view.backgroundColor = MPTheme.surface_dark
        line_number_view.textColor = MPTheme.text_secondary
        line_number_view.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        line_number_view.isEditable = false
        line_number_view.isSelectable = false
        line_number_view.textAlignment = .right
        line_number_view.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        view.addSubview(line_number_view)

        text_view.translatesAutoresizingMaskIntoConstraints = false
        text_view.backgroundColor = MPTheme.background_dark
        text_view.textColor = MPTheme.text_primary
        text_view.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        text_view.autocapitalizationType = .none
        text_view.autocorrectionType = .no
        text_view.smartDashesType = .no
        text_view.smartQuotesType = .no
        text_view.delegate = self
        text_view.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        view.addSubview(text_view)

        NSLayoutConstraint.activate([
            search_bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            search_bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            search_bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            line_number_view.topAnchor.constraint(equalTo: search_bar.bottomAnchor),
            line_number_view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            line_number_view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            line_number_view.widthAnchor.constraint(equalToConstant: 44),

            text_view.topAnchor.constraint(equalTo: search_bar.bottomAnchor),
            text_view.leadingAnchor.constraint(equalTo: line_number_view.trailingAnchor),
            text_view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            text_view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func load_content() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: file_path)),
              let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            text_view.text = "Error: File is not a valid UTF-8 text file."
            return
        }
        text_view.text = content
        update_line_numbers()
    }

    private func update_line_numbers() {
        let count = max(1, text_view.text.components(separatedBy: "\n").count)
        var str = ""
        for i in 1...count {
            str += "\(i)\n"
        }
        line_number_view.text = str
    }

    @objc private func handle_save() {
        guard let data = text_view.text.data(using: .utf8) else { return }
        let bak_path = file_path + ".bak"
        _ = try? FileManager.default.copyItem(atPath: file_path, toPath: bak_path)

        do {
            try data.write(to: URL(fileURLWithPath: file_path), options: .atomic)
            let alert = UIAlertController(title: "Saved", message: "File saved successfully (backup created: .bak).", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        } catch {
            let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    @objc private func toggle_search() {
        is_search_visible.toggle()
        search_bar.isHidden = !is_search_visible
        if is_search_visible {
            search_bar.becomeFirstResponder()
        } else {
            search_bar.resignFirstResponder()
        }
    }
}

extension TextEditorViewController: UITextViewDelegate {
    public func textViewDidChange(_ textView: UITextView) {
        update_line_numbers()
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == text_view {
            line_number_view.contentOffset = text_view.contentOffset
        }
    }
}

extension TextEditorViewController: UISearchBarDelegate {
    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        guard let text = searchBar.text, !text.isEmpty, let full = text_view.text else { return }
        if let range = full.range(of: text, options: .caseInsensitive) {
            let ns_range = NSRange(range, in: full)
            text_view.selectedRange = ns_range
            text_view.scrollRangeToVisible(ns_range)
        }
    }
}
