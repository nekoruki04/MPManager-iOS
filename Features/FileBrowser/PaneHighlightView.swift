import UIKit

public final class PaneHighlightView: UIView {
    public var is_active: Bool = false {
        didSet {
            update_appearance()
        }
    }

    public var active_color: UIColor = MPTheme.primary_accent {
        didSet {
            update_appearance()
        }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        layer.borderWidth = 2.0
        update_appearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func update_appearance() {
        layer.borderColor = is_active ? active_color.cgColor : MPTheme.inactive_pane_border.cgColor
    }
}
