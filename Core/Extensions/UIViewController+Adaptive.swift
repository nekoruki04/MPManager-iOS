import UIKit

public extension UIViewController {
    func present_adaptive_sheet(_ alert: UIAlertController, source_view: UIView? = nil, bar_button_item: UIBarButtonItem? = nil) {
        if let popover = alert.popoverPresentationController {
            if let bbi = bar_button_item {
                popover.barButtonItem = bbi
            } else {
                let target = source_view ?? self.view ?? UIView()
                popover.sourceView = target
                popover.sourceRect = CGRect(x: target.bounds.midX, y: target.bounds.midY, width: 1, height: 1)
                popover.permittedArrowDirections = []
            }
        }
        present(alert, animated: true)
    }
}
