import UIKit
import PDFKit

public final class PdfViewerViewController: UIViewController, PDFViewDelegate, UISearchBarDelegate {
    private let pdf_path: String
    private let pdf_view = PDFView()
    private let search_bar = UISearchBar()
    private let page_label = UILabel()
    private var pdf_document: PDFDocument?
    private var search_results: [PDFSelection] = []
    private var current_search_index: Int = 0

    public init(pdf_path: String) {
        self.pdf_path = pdf_path
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setup_ui()
        load_pdf()
    }

    private func setup_ui() {
        view.backgroundColor = MPTheme.background_dark
        title = (pdf_path as NSString).lastPathComponent

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(handle_close))

        let share_item = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(handle_share))
        let search_item = UIBarButtonItem(barButtonSystemItem: .search, target: self, action: #selector(toggle_search))
        navigationItem.rightBarButtonItems = [share_item, search_item]

        search_bar.translatesAutoresizingMaskIntoConstraints = false
        search_bar.barStyle = .black
        search_bar.placeholder = "Search in PDF..."
        search_bar.delegate = self
        search_bar.isHidden = true
        view.addSubview(search_bar)

        pdf_view.translatesAutoresizingMaskIntoConstraints = false
        pdf_view.autoScales = true
        pdf_view.displayMode = .singlePageContinuous
        pdf_view.displayDirection = .vertical
        pdf_view.delegate = self
        pdf_view.backgroundColor = MPTheme.background_dark
        view.addSubview(pdf_view)

        page_label.translatesAutoresizingMaskIntoConstraints = false
        page_label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        page_label.textColor = .white
        page_label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        page_label.layer.cornerRadius = 10
        page_label.clipsToBounds = true
        page_label.textAlignment = .center
        view.addSubview(page_label)

        NotificationCenter.default.addObserver(self, selector: #selector(page_changed), name: .PDFViewPageChanged, object: pdf_view)

        NSLayoutConstraint.activate([
            search_bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            search_bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            search_bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            pdf_view.topAnchor.constraint(equalTo: search_bar.bottomAnchor),
            pdf_view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pdf_view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pdf_view.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            page_label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            page_label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            page_label.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            page_label.heightAnchor.constraint(equalToConstant: 26)
        ])
    }

    private func load_pdf() {
        let url = URL(fileURLWithPath: pdf_path)
        guard let doc = PDFDocument(url: url) else {
            let alert = UIAlertController(title: "Error", message: "Failed to open PDF document.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in self?.dismiss(animated: true) }))
            present(alert, animated: true)
            return
        }
        self.pdf_document = doc
        pdf_view.document = doc
        update_page_label()
    }

    private func update_page_label() {
        guard let doc = pdf_view.document, let current = pdf_view.currentPage else { return }
        let current_index = doc.index(for: current) + 1
        let total = doc.pageCount
        page_label.text = " \(current_index) / \(total) "
    }

    @objc private func page_changed() {
        update_page_label()
    }

    @objc private func handle_close() {
        dismiss(animated: true)
    }

    @objc private func handle_share() {
        let url = URL(fileURLWithPath: pdf_path)
        let ac = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = ac.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItems?.first
        }
        present(ac, animated: true)
    }

    @objc private func toggle_search() {
        search_bar.isHidden.toggle()
        if !search_bar.isHidden {
            search_bar.becomeFirstResponder()
        } else {
            search_bar.resignFirstResponder()
            pdf_view.highlightedSelections = nil
        }
    }

    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        guard let text = searchBar.text, !text.isEmpty, let doc = pdf_document else { return }
        search_results = doc.findString(text, withOptions: .caseInsensitive)
        if let first = search_results.first {
            pdf_view.go(to: first)
            pdf_view.highlightedSelections = search_results
        }
    }

    public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = nil
        searchBar.resignFirstResponder()
        search_bar.isHidden = true
        pdf_view.highlightedSelections = nil
    }
}
