import UIKit

public final class HexEditorViewController: UIViewController {
    private let file_path: String
    private let text_view = UITextView()
    private var file_data: Data = Data()
    private let page_size = 4096
    private var current_offset = 0

    public init(file_path: String) {
        self.file_path = file_path
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = (file_path as NSString).lastPathComponent + " (Hex)"
        view.backgroundColor = MPTheme.background_dark

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Goto", style: .plain, target: self, action: #selector(handle_goto))

        text_view.translatesAutoresizingMaskIntoConstraints = false
        text_view.backgroundColor = MPTheme.background_dark
        text_view.textColor = MPTheme.text_primary
        text_view.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        text_view.isEditable = false
        view.addSubview(text_view)

        NSLayoutConstraint.activate([
            text_view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            text_view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            text_view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            text_view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        load_data()
    }

    private func load_data() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: file_path), options: .alwaysMapped) else {
            text_view.text = "Failed to load binary data."
            return
        }
        file_data = data
        render_hex_page()
    }

    private func render_hex_page() {
        let max_len = min(file_data.count - current_offset, page_size)
        guard max_len > 0 else {
            text_view.text = "Empty file."
            return
        }

        var result = ""
        let sub = file_data.subdata(in: current_offset..<current_offset + max_len)

        for row in stride(from: 0, to: sub.count, by: 16) {
            let offset_str = String(format: "%08X: ", current_offset + row)
            result += offset_str

            let row_bytes = sub[row..<min(row + 16, sub.count)]
            var hex_part = ""
            var ascii_part = ""

            for (i, b) in row_bytes.enumerated() {
                hex_part += String(format: "%02X ", b)
                if i == 7 { hex_part += " " }
                let char = (b >= 32 && b <= 126) ? Character(UnicodeScalar(b)) : "."
                ascii_part.append(char)
            }

            let pad = 16 - row_bytes.count
            if pad > 0 {
                for i in 0..<pad {
                    hex_part += "   "
                    if (row_bytes.count + i) == 8 { hex_part += " " }
                }
            }

            result += hex_part + " |" + ascii_part + "|\n"
        }

        text_view.text = result
    }

    @objc private func handle_goto() {
        let alert = UIAlertController(title: "Goto Offset", message: "Enter hexadecimal offset (e.g. 0x1000):", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "0x0" }
        alert.addAction(UIAlertAction(title: "Jump", style: .default, handler: { [weak self] _ in
            guard let self = self, let text = alert.textFields?.first?.text else { return }
            let clean = text.lowercased().replacingOccurrences(of: "0x", with: "")
            if let target = Int(clean, radix: 16), target < self.file_data.count {
                self.current_offset = (target / 16) * 16
                self.render_hex_page()
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}
