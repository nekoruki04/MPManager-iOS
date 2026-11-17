import UIKit
import CryptoKit
import CommonCrypto

public final class FilePropertiesViewController: UIViewController {
    private let item: FileItem
    public var on_permissions_changed: (() -> Void)?

    private let scroll_view = UIScrollView()
    private let content_stack = UIStackView()
    private let sha256_label = UILabel()
    private let md5_label = UILabel()

    public init(item: FileItem) {
        self.item = item
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "Properties"
        view.backgroundColor = MPTheme.surface_dark

        setup_ui()
        calculate_checksums()
    }

    private func setup_ui() {
        scroll_view.translatesAutoresizingMaskIntoConstraints = false
        content_stack.translatesAutoresizingMaskIntoConstraints = false
        content_stack.axis = .vertical
        content_stack.spacing = 16

        view.addSubview(scroll_view)
        scroll_view.addSubview(content_stack)

        NSLayoutConstraint.activate([
            scroll_view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll_view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll_view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll_view.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            content_stack.topAnchor.constraint(equalTo: scroll_view.topAnchor, constant: 16),
            content_stack.leadingAnchor.constraint(equalTo: scroll_view.leadingAnchor, constant: 16),
            content_stack.trailingAnchor.constraint(equalTo: scroll_view.trailingAnchor, constant: -16),
            content_stack.bottomAnchor.constraint(equalTo: scroll_view.bottomAnchor, constant: -16),
            content_stack.widthAnchor.constraint(equalTo: scroll_view.widthAnchor, constant: -32)
        ])

        let fields = [
            ("Name", item.name),
            ("Location", (item.path as NSString).deletingLastPathComponent),
            ("Size", item.is_directory ? "Directory" : "\(item.formatted_size) (\(item.size) bytes)"),
            ("Permissions", "\(item.octal_permissions) (\(item.posix_permissions_string))"),
            ("Owner", "\(item.owner_name) (UID \(item.owner_id))"),
            ("Group", "\(item.group_name) (GID \(item.group_id))"),
            ("Modified", item.formatted_date)
        ]

        let info_box = UIStackView()
        info_box.axis = .vertical
        info_box.spacing = 8
        info_box.backgroundColor = MPTheme.background_dark
        info_box.isLayoutMarginsRelativeArrangement = true
        info_box.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        info_box.layer.cornerRadius = 8

        for (k, v) in fields {
            let row = UIStackView()
            row.axis = .horizontal
            let kl = UILabel()
            kl.text = k
            kl.textColor = MPTheme.text_secondary
            kl.font = UIFont.systemFont(ofSize: 13)
            let vl = UILabel()
            vl.text = v
            vl.textColor = MPTheme.text_primary
            vl.font = UIFont.systemFont(ofSize: 13)
            vl.textAlignment = .right
            vl.numberOfLines = 2
            row.addArrangedSubview(kl)
            row.addArrangedSubview(vl)
            info_box.addArrangedSubview(row)
        }
        content_stack.addArrangedSubview(info_box)

        let hash_box = UIStackView()
        hash_box.axis = .vertical
        hash_box.spacing = 8
        hash_box.backgroundColor = MPTheme.background_dark
        hash_box.isLayoutMarginsRelativeArrangement = true
        hash_box.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        hash_box.layer.cornerRadius = 8

        let hash_title = UILabel()
        hash_title.text = "Checksums (Hashes)"
        hash_title.font = UIFont.boldSystemFont(ofSize: 14)
        hash_title.textColor = MPTheme.primary_accent
        hash_box.addArrangedSubview(hash_title)

        sha256_label.text = "SHA-256: Calculating..."
        sha256_label.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        sha256_label.textColor = MPTheme.text_secondary
        sha256_label.numberOfLines = 0
        hash_box.addArrangedSubview(sha256_label)

        md5_label.text = "MD5: Calculating..."
        md5_label.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        md5_label.textColor = MPTheme.text_secondary
        hash_box.addArrangedSubview(md5_label)

        content_stack.addArrangedSubview(hash_box)

        let chmod_btn = UIButton(type: .system)
        chmod_btn.setTitle("Change Permissions (Octal)", for: .normal)
        chmod_btn.backgroundColor = MPTheme.primary_accent
        chmod_btn.setTitleColor(.white, for: .normal)
        chmod_btn.layer.cornerRadius = 8
        chmod_btn.heightAnchor.constraint(equalToConstant: 44).isActive = true
        chmod_btn.addTarget(self, action: #selector(handle_chmod), for: .touchUpInside)
        content_stack.addArrangedSubview(chmod_btn)
    }

    private func calculate_checksums() {
        if item.is_directory {
            sha256_label.text = "SHA-256: N/A (Directory)"
            md5_label.text = "MD5: N/A (Directory)"
            return
        }

        Task.detached(priority: .userInitiated) { [path = item.path] in
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
                await MainActor.run {
                    self.sha256_label.text = "SHA-256: Read error"
                    self.md5_label.text = "MD5: Read error"
                }
                return
            }
            let sha = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()

            var md5_buf = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            data.withUnsafeBytes { _ = CC_MD5($0.baseAddress, CC_LONG(data.count), &md5_buf) }
            let md5_str = md5_buf.map { String(format: "%02x", $0) }.joined()

            await MainActor.run {
                self.sha256_label.text = "SHA-256:\n\(sha)"
                self.md5_label.text = "MD5:\n\(md5_str)"
            }
        }
    }

    @objc private func handle_chmod() {
        let alert = UIAlertController(title: "Change Permissions", message: "Enter octal mode (e.g. 0755, 0644):", preferredStyle: .alert)
        alert.addTextField { $0.text = self.item.octal_permissions }
        alert.addAction(UIAlertAction(title: "Apply", style: .default, handler: { [weak self] _ in
            guard let self = self,
                  let text = alert.textFields?.first?.text,
                  let octal = UInt16(text, radix: 8) else { return }
            do {
                try FileSystemProvider.shared.set_permissions(mode_t(octal), at: self.item.path)
                self.on_permissions_changed?()
                self.dismiss(animated: true)
            } catch {
                let err_alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                err_alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(err_alert, animated: true)
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}
