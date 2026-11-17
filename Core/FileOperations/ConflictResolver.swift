import Foundation

public enum ConflictResolution: Sendable {
    case replace
    case skip
    case keepBoth
}

public struct ConflictResolver: Sendable {
    public static func resolve_destination(source: String, destination_directory: String, resolution: ConflictResolution) -> String? {
        let filename = (source as NSString).lastPathComponent
        let target_path = (destination_directory as NSString).appendingPathComponent(filename)

        if !FileManager.default.fileExists(atPath: target_path) {
            return target_path
        }

        switch resolution {
        case .replace:
            return target_path
        case .skip:
            return nil
        case .keepBoth:
            return generate_unique_name(for: target_path)
        }
    }

    public static func generate_unique_name(for target_path: String) -> String {
        let parent = (target_path as NSString).deletingLastPathComponent
        let name = (target_path as NSString).lastPathComponent
        let ext = (name as NSString).pathExtension
        let base = (name as NSString).deletingPathExtension

        var counter = 1
        var new_path = target_path

        while FileManager.default.fileExists(atPath: new_path) {
            let new_name: String
            if ext.isEmpty {
                new_name = "\(base) (\(counter))"
            } else {
                new_name = "\(base) (\(counter)).\(ext)"
            }
            new_path = (parent as NSString).appendingPathComponent(new_name)
            counter += 1
        }
        return new_path
    }
}
