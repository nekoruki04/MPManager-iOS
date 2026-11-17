import UIKit

public final class FileCell: UITableViewCell {
    public static let reuse_id = "MPFileCell"

    private let icon_view = UIImageView()
    private let title_label = UILabel()
    private let subtitle_label = UILabel()
    private let checkmark_view = UIImageView()

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup_views()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup_views() {
        backgroundColor = .clear
        selectionStyle = .none

        icon_view.translatesAutoresizingMaskIntoConstraints = false
        icon_view.contentMode = .scaleAspectFit
        contentView.addSubview(icon_view)

        let text_stack = UIStackView()
        text_stack.translatesAutoresizingMaskIntoConstraints = false
        text_stack.axis = .vertical
        text_stack.spacing = 3

        title_label.textColor = MPTheme.text_primary
        title_label.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        title_label.lineBreakMode = .byTruncatingMiddle

        subtitle_label.textColor = MPTheme.text_secondary
        subtitle_label.font = UIFont.systemFont(ofSize: 12, weight: .regular)

        text_stack.addArrangedSubview(title_label)
        text_stack.addArrangedSubview(subtitle_label)
        contentView.addSubview(text_stack)

        checkmark_view.translatesAutoresizingMaskIntoConstraints = false
        checkmark_view.contentMode = .scaleAspectFit
        checkmark_view.image = UIImage(systemName: "checkmark.circle.fill")?.withTintColor(MPTheme.primary_accent, renderingMode: .alwaysOriginal)
        checkmark_view.isHidden = true
        contentView.addSubview(checkmark_view)

        NSLayoutConstraint.activate([
            icon_view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            icon_view.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            icon_view.widthAnchor.constraint(equalToConstant: 28),
            icon_view.heightAnchor.constraint(equalToConstant: 28),

            text_stack.leadingAnchor.constraint(equalTo: icon_view.trailingAnchor, constant: 12),
            text_stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            text_stack.trailingAnchor.constraint(equalTo: checkmark_view.leadingAnchor, constant: -8),

            checkmark_view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            checkmark_view.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkmark_view.widthAnchor.constraint(equalToConstant: 22),
            checkmark_view.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    public func configure(with item: FileItem, is_selected: Bool) {
        title_label.text = item.name
        let date_str = item.formatted_date
        let size_str = item.is_directory ? "<DIR>" : item.formatted_size
        subtitle_label.text = "\(size_str)  •  \(date_str)  •  \(item.octal_permissions)"
        icon_view.image = MPTheme.icon_for_extension(item.file_extension, is_dir: item.is_directory, is_sym: item.is_symlink)
        checkmark_view.isHidden = !is_selected
        contentView.backgroundColor = is_selected ? MPTheme.surface_variant : .clear
    }
}
