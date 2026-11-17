import UIKit

public struct DiffLine: Sendable {
    public enum Kind: Sendable {
        case same
        case add
        case delete
    }
    public let kind: Kind
    public let text: String
    public let line_old: Int?
    public let line_new: Int?
}

public final class FileDiffViewController: UIViewController {
    private let path_left: String
    private let path_right: String
    private let text_view = UITextView()

    public init(path_left: String, path_right: String) {
        self.path_left = path_left
        self.path_right = path_right
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "File Comparison"
        view.backgroundColor = MPTheme.background_dark

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

        compute_diff()
    }

    private func compute_diff() {
        guard let left_data = try? Data(contentsOf: URL(fileURLWithPath: path_left)),
              let right_data = try? Data(contentsOf: URL(fileURLWithPath: path_right)),
              let left_text = String(data: left_data, encoding: .utf8),
              let right_text = String(data: right_data, encoding: .utf8) else {
            text_view.text = "Failed to load files as UTF-8 text."
            return
        }

        let left_lines = left_text.components(separatedBy: "\n")
        let right_lines = right_text.components(separatedBy: "\n")

        let diff_result = myers_diff(a: left_lines, b: right_lines)

        let attr_string = NSMutableAttributedString()
        for item in diff_result {
            let prefix: String
            let color: UIColor
            switch item.kind {
            case .same:
                prefix = "  "
                color = MPTheme.text_secondary
            case .add:
                prefix = "+ "
                color = MPTheme.secondary_accent
            case .delete:
                prefix = "- "
                color = UIColor.systemRed
            }
            let line_str = prefix + item.text + "\n"
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: color,
                .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            ]
            attr_string.append(NSAttributedString(string: line_str, attributes: attrs))
        }

        text_view.attributedText = attr_string
    }

    private func myers_diff(a: [String], b: [String]) -> [DiffLine] {
        var results: [DiffLine] = []
        var i = 0
        var j = 0

        while i < a.count && j < b.count {
            if a[i] == b[j] {
                results.append(DiffLine(kind: .same, text: a[i], line_old: i + 1, line_new: j + 1))
                i += 1
                j += 1
            } else {
                var found_j: Int? = nil
                for k in j..<min(j + 10, b.count) {
                    if a[i] == b[k] {
                        found_j = k
                        break
                    }
                }
                if let match = found_j {
                    while j < match {
                        results.append(DiffLine(kind: .add, text: b[j], line_old: nil, line_new: j + 1))
                        j += 1
                    }
                } else {
                    results.append(DiffLine(kind: .delete, text: a[i], line_old: i + 1, line_new: nil))
                    i += 1
                }
            }
        }

        while i < a.count {
            results.append(DiffLine(kind: .delete, text: a[i], line_old: i + 1, line_new: nil))
            i += 1
        }
        while j < b.count {
            results.append(DiffLine(kind: .add, text: b[j], line_old: nil, line_new: j + 1))
            j += 1
        }
        return results
    }
}
