import UIKit

public struct MPTheme: Sendable {
    public static let primary_accent = UIColor(red: 0.13, green: 0.59, blue: 0.95, alpha: 1.0)
    public static let secondary_accent = UIColor(red: 0.30, green: 0.69, blue: 0.31, alpha: 1.0)
    public static let background_dark = UIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1.0)
    public static let surface_dark = UIColor(red: 0.14, green: 0.14, blue: 0.14, alpha: 1.0)
    public static let surface_variant = UIColor(red: 0.22, green: 0.22, blue: 0.22, alpha: 1.0)
    public static let border_color = UIColor(red: 0.30, green: 0.30, blue: 0.30, alpha: 1.0)
    public static let active_pane_border = UIColor(red: 0.13, green: 0.59, blue: 0.95, alpha: 1.0)
    public static let inactive_pane_border = UIColor.clear

    public static let folder_amber = UIColor(red: 1.0, green: 0.63, blue: 0.0, alpha: 1.0)
    public static let archive_purple = UIColor(red: 0.61, green: 0.15, blue: 0.69, alpha: 1.0)
    public static let binary_teal = UIColor(red: 0.0, green: 0.59, blue: 0.53, alpha: 1.0)
    public static let image_green = UIColor(red: 0.30, green: 0.69, blue: 0.31, alpha: 1.0)
    public static let text_blue = UIColor(red: 0.13, green: 0.59, blue: 0.95, alpha: 1.0)
    public static let apk_green = UIColor(red: 0.30, green: 0.69, blue: 0.31, alpha: 1.0)
    public static let text_primary = UIColor.white
    public static let text_secondary = UIColor(white: 0.70, alpha: 1.0)

    public static func icon_for_extension(_ ext: String, is_dir: Bool, is_sym: Bool) -> UIImage {
        if is_dir {
            return UIImage(systemName: is_sym ? "folder.badge.gearshape" : "folder.fill")?.withTintColor(folder_amber, renderingMode: .alwaysOriginal) ?? UIImage()
        }
        let lower = ext.lowercased()
        switch lower {
        case "zip", "7z", "rar", "tar", "gz", "bz2", "xz", "zst", "deb", "ipa":
            return UIImage(systemName: "archivebox.fill")?.withTintColor(archive_purple, renderingMode: .alwaysOriginal) ?? UIImage()
        case "apk", "xapk", "apks":
            return UIImage(systemName: "app.badge.fill")?.withTintColor(apk_green, renderingMode: .alwaysOriginal) ?? UIImage()
        case "dex", "so", "dylib", "elf", "o", "a", "bin":
            return UIImage(systemName: "cpu.fill")?.withTintColor(binary_teal, renderingMode: .alwaysOriginal) ?? UIImage()
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "svg":
            return UIImage(systemName: "photo.fill")?.withTintColor(image_green, renderingMode: .alwaysOriginal) ?? UIImage()
        case "mp3", "m4a", "flac", "wav", "aac", "ogg":
            return UIImage(systemName: "music.note")?.withTintColor(primary_accent, renderingMode: .alwaysOriginal) ?? UIImage()
        case "mp4", "mkv", "mov", "avi":
            return UIImage(systemName: "film.fill")?.withTintColor(primary_accent, renderingMode: .alwaysOriginal) ?? UIImage()
        case "txt", "md", "json", "xml", "plist", "log", "c", "cpp", "h", "swift", "java", "kt", "py", "sh":
            return UIImage(systemName: "doc.text.fill")?.withTintColor(text_blue, renderingMode: .alwaysOriginal) ?? UIImage()
        case "sqlite", "db", "sqlite3":
            return UIImage(systemName: "cylinder.split.1x2.fill")?.withTintColor(folder_amber, renderingMode: .alwaysOriginal) ?? UIImage()
        default:
            return UIImage(systemName: "doc.fill")?.withTintColor(.systemGray, renderingMode: .alwaysOriginal) ?? UIImage()
        }
    }
}
