import UIKit

public final class SettingsViewController: UIViewController {
    private let scroll_view = UIScrollView()
    private let content_stack = UIStackView()

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        view.backgroundColor = MPTheme.surface_dark

        setup_ui()
    }

    private func setup_ui() {
        scroll_view.translatesAutoresizingMaskIntoConstraints = false
        content_stack.translatesAutoresizingMaskIntoConstraints = false
        content_stack.axis = .vertical
        content_stack.spacing = 20

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

        add_env_section()
        add_about_section()
    }

    private func add_env_section() {
        let sec_title = UILabel()
        sec_title.text = "Jailbreak Environment"
        sec_title.font = UIFont.boldSystemFont(ofSize: 14)
        sec_title.textColor = MPTheme.primary_accent
        content_stack.addArrangedSubview(sec_title)

        let box = UIStackView()
        box.axis = .vertical
        box.spacing = 8
        box.backgroundColor = MPTheme.background_dark
        box.isLayoutMarginsRelativeArrangement = true
        box.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        box.layer.cornerRadius = 8

        let flavor = JailbreakEnvironment.current_flavor.description
        let creds = JailbreakEnvironment.credentials.summary
        let jb_path = RootlessPaths.resolved_jailbreak_path

        let rows = [
            ("Flavor", flavor),
            ("Process Credentials", creds),
            ("Rootless Base Path", jb_path)
        ]

        for (k, v) in rows {
            let row = UIStackView()
            row.axis = .vertical
            row.spacing = 2
            let kl = UILabel()
            kl.text = k
            kl.textColor = MPTheme.text_secondary
            kl.font = UIFont.systemFont(ofSize: 12)
            let vl = UILabel()
            vl.text = v
            vl.textColor = MPTheme.text_primary
            vl.font = UIFont.systemFont(ofSize: 13, weight: .medium)
            vl.numberOfLines = 0
            row.addArrangedSubview(kl)
            row.addArrangedSubview(vl)
            box.addArrangedSubview(row)
        }
        content_stack.addArrangedSubview(box)
    }

    private func add_about_section() {
        let sec_title = UILabel()
        sec_title.text = "About & Attribution"
        sec_title.font = UIFont.boldSystemFont(ofSize: 14)
        sec_title.textColor = MPTheme.primary_accent
        content_stack.addArrangedSubview(sec_title)

        let box = UIStackView()
        box.axis = .vertical
        box.spacing = 10
        box.backgroundColor = MPTheme.background_dark
        box.isLayoutMarginsRelativeArrangement = true
        box.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        box.layer.cornerRadius = 8

        let title_lbl = UILabel()
        title_lbl.text = "MP Manager for iOS Rootless v1.0.0"
        title_lbl.font = UIFont.boldSystemFont(ofSize: 15)
        title_lbl.textColor = MPTheme.text_primary
        box.addArrangedSubview(title_lbl)

        let desc_lbl = UILabel()
        desc_lbl.text = "Native dual-pane file manager, APK tools, and MCP server for iOS jailbreak (Dopamine 2, Dopamine 3, RootHide)."
        desc_lbl.font = UIFont.systemFont(ofSize: 13)
        desc_lbl.textColor = MPTheme.text_secondary
        desc_lbl.numberOfLines = 0
        box.addArrangedSubview(desc_lbl)

        let credits = [
            ("Original Author", "Abdurazaaq Mohammed (@AbdurazaaqMohammed)"),
            ("iOS Port Maintainer", "nekoruki (@nekoruki04)"),
            ("License", "GNU General Public License v3.0 (GPLv3)")
        ]

        for (k, v) in credits {
            let row = UIStackView()
            row.axis = .horizontal
            let kl = UILabel()
            kl.text = k
            kl.textColor = MPTheme.text_secondary
            kl.font = UIFont.systemFont(ofSize: 13)
            let vl = UILabel()
            vl.text = v
            vl.textColor = MPTheme.text_primary
            vl.font = UIFont.systemFont(ofSize: 13, weight: .medium)
            vl.textAlignment = .right
            row.addArrangedSubview(kl)
            row.addArrangedSubview(vl)
            box.addArrangedSubview(row)
        }
        content_stack.addArrangedSubview(box)
    }
}
