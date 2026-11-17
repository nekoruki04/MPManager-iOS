import Foundation

public enum OperationType: String, Sendable {
    case copy = "Copy"
    case move = "Move"
    case delete = "Delete"
    case rename = "Rename"
    case extract = "Extract"
    case compress = "Compress"
    case chmod = "Permissions"
}

public struct OperationProgress: Sendable {
    public let operation_id: UUID
    public let type: OperationType
    public let current_item: String
    public let completed_units: Int64
    public let total_units: Int64

    public var percentage: Double {
        guard total_units > 0 else { return 0.0 }
        return min(1.0, max(0.0, Double(completed_units) / Double(total_units)))
    }

    public var formatted_percentage: String {
        String(format: "%.1f%%", percentage * 100.0)
    }

    public init(operation_id: UUID, type: OperationType, current_item: String, completed_units: Int64, total_units: Int64) {
        self.operation_id = operation_id
        self.type = type
        self.current_item = current_item
        self.completed_units = completed_units
        self.total_units = total_units
    }
}

public protocol FileOperationDelegate: AnyObject, Sendable {
    func operation_did_update_progress(_ progress: OperationProgress)
    func operation_did_complete(_ operation_id: UUID)
    func operation_did_fail(_ operation_id: UUID, error: Error)
}
