import UIKit
import ImageIO

public final class ImageViewerViewController: UIViewController, UIScrollViewDelegate {
    private var image_paths: [String] = []
    private var current_index: Int = 0

    private let scroll_view = UIScrollView()
    private let image_view = UIImageView()
    private let top_bar = UIView()
    private let bottom_bar = UIView()
    private let title_label = UILabel()
    private let count_label = UILabel()

    public init(current_path: String, all_image_paths: [String] = []) {
        if all_image_paths.isEmpty {
            self.image_paths = [current_path]
            self.current_index = 0
        } else {
            self.image_paths = all_image_paths
            if let idx = all_image_paths.firstIndex(of: current_path) {
                self.current_index = idx
            } else {
                self.current_index = 0
            }
        }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setup_ui()
        load_current_image()
    }

    private func setup_ui() {
        view.backgroundColor = .black

        scroll_view.translatesAutoresizingMaskIntoConstraints = false
        scroll_view.delegate = self
        scroll_view.minimumZoomScale = 1.0
        scroll_view.maximumZoomScale = 5.0
        scroll_view.showsHorizontalScrollIndicator = false
        scroll_view.showsVerticalScrollIndicator = false
        view.addSubview(scroll_view)

        image_view.translatesAutoresizingMaskIntoConstraints = false
        image_view.contentMode = .scaleAspectFit
        image_view.isUserInteractionEnabled = true
        scroll_view.addSubview(image_view)

        let double_tap = UITapGestureRecognizer(target: self, action: #selector(handle_double_tap(_:)))
        double_tap.numberOfTapsRequired = 2
        scroll_view.addGestureRecognizer(double_tap)

        let swipe_left = UISwipeGestureRecognizer(target: self, action: #selector(handle_swipe_left))
        swipe_left.direction = .left
        view.addGestureRecognizer(swipe_left)

        let swipe_right = UISwipeGestureRecognizer(target: self, action: #selector(handle_swipe_right))
        swipe_right.direction = .right
        view.addGestureRecognizer(swipe_right)

        setup_navigation_bars()

        NSLayoutConstraint.activate([
            scroll_view.topAnchor.constraint(equalTo: view.topAnchor),
            scroll_view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll_view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll_view.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            image_view.centerXAnchor.constraint(equalTo: scroll_view.centerXAnchor),
            image_view.centerYAnchor.constraint(equalTo: scroll_view.centerYAnchor),
            image_view.widthAnchor.constraint(equalTo: scroll_view.widthAnchor),
            image_view.heightAnchor.constraint(equalTo: scroll_view.heightAnchor)
        ])
    }

    private func setup_navigation_bars() {
        top_bar.translatesAutoresizingMaskIntoConstraints = false
        top_bar.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        view.addSubview(top_bar)

        bottom_bar.translatesAutoresizingMaskIntoConstraints = false
        bottom_bar.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        view.addSubview(bottom_bar)

        let close_btn = UIButton(type: .system)
        close_btn.translatesAutoresizingMaskIntoConstraints = false
        close_btn.setImage(UIImage(systemName: "xmark"), for: .normal)
        close_btn.tintColor = .white
        close_btn.addTarget(self, action: #selector(handle_close), for: .touchUpInside)
        top_bar.addSubview(close_btn)

        title_label.translatesAutoresizingMaskIntoConstraints = false
        title_label.textColor = .white
        title_label.font = .systemFont(ofSize: 14, weight: .medium)
        title_label.lineBreakMode = .byTruncatingMiddle
        top_bar.addSubview(title_label)

        count_label.translatesAutoresizingMaskIntoConstraints = false
        count_label.textColor = UIColor.white.withAlphaComponent(0.7)
        count_label.font = .systemFont(ofSize: 12)
        top_bar.addSubview(count_label)

        let info_btn = UIButton(type: .system)
        info_btn.translatesAutoresizingMaskIntoConstraints = false
        info_btn.setImage(UIImage(systemName: "info.circle"), for: .normal)
        info_btn.tintColor = .white
        info_btn.addTarget(self, action: #selector(show_exif_info), for: .touchUpInside)
        top_bar.addSubview(info_btn)

        let share_btn = UIButton(type: .system)
        share_btn.translatesAutoresizingMaskIntoConstraints = false
        share_btn.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        share_btn.tintColor = .white
        share_btn.addTarget(self, action: #selector(handle_share), for: .touchUpInside)
        bottom_bar.addSubview(share_btn)

        let rotate_btn = UIButton(type: .system)
        rotate_btn.translatesAutoresizingMaskIntoConstraints = false
        rotate_btn.setImage(UIImage(systemName: "rotate.right"), for: .normal)
        rotate_btn.tintColor = .white
        rotate_btn.addTarget(self, action: #selector(handle_rotate), for: .touchUpInside)
        bottom_bar.addSubview(rotate_btn)

        let flip_btn = UIButton(type: .system)
        flip_btn.translatesAutoresizingMaskIntoConstraints = false
        flip_btn.setImage(UIImage(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right"), for: .normal)
        flip_btn.tintColor = .white
        flip_btn.addTarget(self, action: #selector(handle_flip), for: .touchUpInside)
        bottom_bar.addSubview(flip_btn)

        let strip_btn = UIButton(type: .system)
        strip_btn.translatesAutoresizingMaskIntoConstraints = false
        strip_btn.setTitle("Strip EXIF", for: .normal)
        strip_btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        strip_btn.tintColor = MPTheme.primary_accent
        strip_btn.addTarget(self, action: #selector(handle_strip_exif), for: .touchUpInside)
        bottom_bar.addSubview(strip_btn)

        NSLayoutConstraint.activate([
            top_bar.topAnchor.constraint(equalTo: view.topAnchor),
            top_bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            top_bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            top_bar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),

            close_btn.leadingAnchor.constraint(equalTo: top_bar.leadingAnchor, constant: 16),
            close_btn.bottomAnchor.constraint(equalTo: top_bar.bottomAnchor, constant: -10),
            close_btn.widthAnchor.constraint(equalToConstant: 24),
            close_btn.heightAnchor.constraint(equalToConstant: 24),

            title_label.leadingAnchor.constraint(equalTo: close_btn.trailingAnchor, constant: 12),
            title_label.trailingAnchor.constraint(equalTo: info_btn.leadingAnchor, constant: -12),
            title_label.topAnchor.constraint(equalTo: close_btn.topAnchor, constant: -6),

            count_label.leadingAnchor.constraint(equalTo: title_label.leadingAnchor),
            count_label.topAnchor.constraint(equalTo: title_label.bottomAnchor, constant: 2),

            info_btn.trailingAnchor.constraint(equalTo: top_bar.trailingAnchor, constant: -16),
            info_btn.centerYAnchor.constraint(equalTo: close_btn.centerYAnchor),
            info_btn.widthAnchor.constraint(equalToConstant: 26),
            info_btn.heightAnchor.constraint(equalToConstant: 26),

            bottom_bar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottom_bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottom_bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottom_bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -48),

            share_btn.leadingAnchor.constraint(equalTo: bottom_bar.leadingAnchor, constant: 20),
            share_btn.topAnchor.constraint(equalTo: bottom_bar.topAnchor, constant: 10),
            share_btn.widthAnchor.constraint(equalToConstant: 28),
            share_btn.heightAnchor.constraint(equalToConstant: 28),

            rotate_btn.leadingAnchor.constraint(equalTo: share_btn.trailingAnchor, constant: 28),
            rotate_btn.centerYAnchor.constraint(equalTo: share_btn.centerYAnchor),
            rotate_btn.widthAnchor.constraint(equalToConstant: 28),
            rotate_btn.heightAnchor.constraint(equalToConstant: 28),

            flip_btn.leadingAnchor.constraint(equalTo: rotate_btn.trailingAnchor, constant: 28),
            flip_btn.centerYAnchor.constraint(equalTo: share_btn.centerYAnchor),
            flip_btn.widthAnchor.constraint(equalToConstant: 28),
            flip_btn.heightAnchor.constraint(equalToConstant: 28),

            strip_btn.trailingAnchor.constraint(equalTo: bottom_bar.trailingAnchor, constant: -20),
            strip_btn.centerYAnchor.constraint(equalTo: share_btn.centerYAnchor)
        ])
    }

    private func load_current_image() {
        guard current_index >= 0 && current_index < image_paths.count else { return }
        let path = image_paths[current_index]
        let name = (path as NSString).lastPathComponent
        title_label.text = name
        count_label.text = "\(current_index + 1) / \(image_paths.count)"

        scroll_view.zoomScale = 1.0
        if let img = UIImage(contentsOfFile: path) {
            image_view.image = img
        } else {
            image_view.image = UIImage(systemName: "photo")
        }
    }

    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return image_view
    }

    @objc private func handle_double_tap(_ gesture: UITapGestureRecognizer) {
        if scroll_view.zoomScale > 1.0 {
            scroll_view.setZoomScale(1.0, animated: true)
        } else {
            let point = gesture.location(in: image_view)
            let rect = CGRect(x: point.x - 50, y: point.y - 50, width: 100, height: 100)
            scroll_view.zoom(to: rect, animated: true)
        }
    }

    @objc private func handle_swipe_left() {
        guard current_index < image_paths.count - 1 else { return }
        current_index += 1
        load_current_image()
    }

    @objc private func handle_swipe_right() {
        guard current_index > 0 else { return }
        current_index -= 1
        load_current_image()
    }

    @objc private func handle_close() {
        dismiss(animated: true)
    }

    @objc private func handle_share() {
        guard current_index < image_paths.count else { return }
        let path = image_paths[current_index]
        let url = URL(fileURLWithPath: path)
        let ac = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = ac.popoverPresentationController {
            popover.sourceView = bottom_bar
            popover.sourceRect = bottom_bar.bounds
        }
        present(ac, animated: true)
    }

    @objc private func show_exif_info() {
        guard current_index < image_paths.count else { return }
        let path = image_paths[current_index]
        let url = URL(fileURLWithPath: path) as CFURL
        guard let source = CGImageSourceCreateWithURL(url, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            show_alert(title: "EXIF", message: "No EXIF metadata found in this image.")
            return
        }

        var lines: [String] = []
        if let w = props[kCGImagePropertyPixelWidth] as? Int,
           let h = props[kCGImagePropertyPixelHeight] as? Int {
            lines.append("Dimensions: \(w) x \(h)")
        }
        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            if let date = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
                lines.append("Date: \(date)")
            }
            if let f_num = exif[kCGImagePropertyExifFNumber] as? Double {
                lines.append("Aperture: f/\(f_num)")
            }
            if let exp = exif[kCGImagePropertyExifExposureTime] as? Double {
                lines.append("Exposure: \(exp)s")
            }
            if let iso = exif[kCGImagePropertyExifISOSpeedRatings] as? [Int], let first_iso = iso.first {
                lines.append("ISO: \(first_iso)")
            }
        }
        if let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            if let make = tiff[kCGImagePropertyTIFFMake] as? String {
                lines.append("Camera: \(make)")
            }
            if let model = tiff[kCGImagePropertyTIFFModel] as? String {
                lines.append("Model: \(model)")
            }
        }
        if lines.isEmpty {
            lines.append("No common metadata tags present.")
        }

        show_alert(title: "EXIF Properties", message: lines.joined(separator: "\n"))
    }

    @objc private func handle_rotate() {
        guard let img = image_view.image, current_index < image_paths.count else { return }
        guard let rotated = rotate_image(img, angle: .pi / 2) else { return }
        image_view.image = rotated
        save_modified_image(rotated)
    }

    @objc private func handle_flip() {
        guard let img = image_view.image, current_index < image_paths.count else { return }
        guard let flipped = flip_image(img, horizontal: true) else { return }
        image_view.image = flipped
        save_modified_image(flipped)
    }

    @objc private func handle_strip_exif() {
        guard current_index < image_paths.count else { return }
        let path = image_paths[current_index]
        guard let img = UIImage(contentsOfFile: path),
              let data = img.jpegData(compressionQuality: 0.95) else {
            show_alert(title: "Error", message: "Failed to convert image for EXIF stripping.")
            return
        }
        do {
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            show_alert(title: "Success", message: "EXIF metadata stripped successfully.")
        } catch {
            show_alert(title: "Error", message: error.localizedDescription)
        }
    }

    private func save_modified_image(_ img: UIImage) {
        guard current_index < image_paths.count else { return }
        let path = image_paths[current_index]
        guard let data = img.jpegData(compressionQuality: 0.95) else { return }
        try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    private func rotate_image(_ image: UIImage, angle: CGFloat) -> UIImage? {
        var new_size = CGRect(origin: .zero, size: image.size)
            .applying(CGAffineTransform(rotationAngle: angle)).size
        new_size.width = floor(new_size.width)
        new_size.height = floor(new_size.height)

        UIGraphicsBeginImageContextWithOptions(new_size, false, image.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        context.translateBy(x: new_size.width / 2, y: new_size.height / 2)
        context.rotate(by: angle)
        image.draw(in: CGRect(x: -image.size.width / 2, y: -image.size.height / 2, width: image.size.width, height: image.size.height))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }

    private func flip_image(_ image: UIImage, horizontal: Bool) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        if horizontal {
            context.translateBy(x: image.size.width, y: 0)
            context.scaleBy(x: -1.0, y: 1.0)
        } else {
            context.translateBy(x: 0, y: image.size.height)
            context.scaleBy(x: 1.0, y: -1.0)
        }
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }

    private func show_alert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
