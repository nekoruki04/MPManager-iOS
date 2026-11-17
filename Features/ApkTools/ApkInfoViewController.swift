import UIKit

public final class ApkInfoViewController: UIViewController {
    private let apk_path: String
    private var info: ApkPackageInfo?
    public var on_browse_apk: ((String) -> Void)?

    private let scroll_view = UIScrollView()
    private let content_stack = UIStackView()

    public init(apk_path: String) {
        self.apk_path = apk_path
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "APK Information"
        view.backgroundColor = MPTheme.surface_dark

        setup_ui()
        load_info()
    }

    private func setup_ui() {
        scroll_view.translatesAutoresizingMaskIntoConstraints = false
        content_stack.translatesAutoresizingMaskIntoConstraints = false
        content_stack.axis = .vertical
        content_stack.spacing = 16
        content_stack.alignment = .fill

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
    }

    private func load_info() {
        do {
            let data = try ApkInspector.shared.inspect_apk(at: apk_path)
            self.info = data
            render_info(data)
        } catch {
            let err_label = UILabel()
            err_label.textColor = .systemRed
            err_label.text = "Failed to inspect APK: \(error.localizedDescription)"
            content_stack.addArrangedSubview(err_label)
        }
    }

    private func render_info(_ data: ApkPackageInfo) {
        let header_row = UIStackView()
        header_row.axis = .horizontal
        header_row.spacing = 16
        header_row.alignment = .center

        let icon_view = UIImageView(image: UIImage(systemName: "app.badge.fill")?.withTintColor(MPTheme.apk_green, renderingMode: .alwaysOriginal))
        icon_view.translatesAutoresizingMaskIntoConstraints = false
        icon_view.widthAnchor.constraint(equalToConstant: 48).isActive = true
        icon_view.heightAnchor.constraint(equalToConstant: 48).isActive = true
        header_row.addArrangedSubview(icon_view)

        let title_stack = UIStackView()
        title_stack.axis = .vertical
        title_stack.spacing = 4

        let name_label = UILabel()
        name_label.text = data.application_label
        name_label.font = UIFont.boldSystemFont(ofSize: 18)
        name_label.textColor = MPTheme.text_primary

        let pkg_label = UILabel()
        pkg_label.text = data.package_name
        pkg_label.font = UIFont.systemFont(ofSize: 13)
        pkg_label.textColor = MPTheme.text_secondary

        title_stack.addArrangedSubview(name_label)
        title_stack.addArrangedSubview(pkg_label)
        header_row.addArrangedSubview(title_stack)

        content_stack.addArrangedSubview(header_row)

        let details = [
            ("Version Name", data.version_name),
            ("Version Code", data.version_code),
            ("Min SDK", data.min_sdk),
            ("Target SDK", data.target_sdk),
            ("DEX Files", "\(data.dex_count)"),
            ("V1 Signature", data.has_v1_signature ? "Present" : "Missing"),
            ("V2/V3 Signature", data.has_v2_signature ? "Verified" : "Missing"),
            ("Native ABIs", data.native_architectures.isEmpty ? "None" : data.native_architectures.joined(separator: ", ")),
            ("Total Entries", "\(data.file_count) files")
        ]

        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 10
        grid.backgroundColor = MPTheme.background_dark
        grid.isLayoutMarginsRelativeArrangement = true
        grid.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        grid.layer.cornerRadius = 8

        for (k, v) in details {
            let row = UIStackView()
            row.axis = .horizontal
            let kl = UILabel()
            kl.text = k
            kl.textColor = MPTheme.text_secondary
            kl.font = UIFont.systemFont(ofSize: 14)
            let vl = UILabel()
            vl.text = v
            vl.textColor = MPTheme.text_primary
            vl.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            vl.textAlignment = .right
            row.addArrangedSubview(kl)
            row.addArrangedSubview(vl)
            grid.addArrangedSubview(row)
        }
        content_stack.addArrangedSubview(grid)

        let browse_btn = UIButton(type: .system)
        browse_btn.setTitle("View Files in APK (Dual Pane)", for: .normal)
        browse_btn.backgroundColor = MPTheme.primary_accent
        browse_btn.setTitleColor(.white, for: .normal)
        browse_btn.layer.cornerRadius = 8
        browse_btn.heightAnchor.constraint(equalToConstant: 44).isActive = true
        browse_btn.addTarget(self, action: #selector(handle_browse), for: .touchUpInside)
        content_stack.addArrangedSubview(browse_btn)
    }

    @objc private func handle_browse() {
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.on_browse_apk?(self.apk_path)
        }
    }
}
