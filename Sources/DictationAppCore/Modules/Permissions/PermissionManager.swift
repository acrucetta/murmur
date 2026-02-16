public enum PermissionStatus: Equatable, Sendable {
    case authorized
    case denied
    case notDetermined
}

public struct PermissionSnapshot: Equatable, Sendable {
    public var microphone: PermissionStatus
    public var accessibility: PermissionStatus
    public var inputMonitoring: PermissionStatus

    public static let allGranted = PermissionSnapshot(
        microphone: .authorized,
        accessibility: .authorized,
        inputMonitoring: .authorized
    )

    public static let allNotDetermined = PermissionSnapshot(
        microphone: .notDetermined,
        accessibility: .notDetermined,
        inputMonitoring: .notDetermined
    )

    public var allGranted: Bool {
        microphone == .authorized
            && accessibility == .authorized
            && inputMonitoring == .authorized
    }

    public init(microphone: PermissionStatus, accessibility: PermissionStatus, inputMonitoring: PermissionStatus) {
        self.microphone = microphone
        self.accessibility = accessibility
        self.inputMonitoring = inputMonitoring
    }
}

public protocol PermissionManaging {
    func currentStatus() -> PermissionSnapshot
    func requestMissingPermissions()
}

public final class PermissionManager: PermissionManaging {
    private var snapshot: PermissionSnapshot

    public init(initialSnapshot: PermissionSnapshot = .allNotDetermined) {
        snapshot = initialSnapshot
    }

    public func currentStatus() -> PermissionSnapshot {
        snapshot
    }

    public func requestMissingPermissions() {
        if snapshot.microphone == .notDetermined {
            snapshot.microphone = .authorized
        }
        if snapshot.accessibility == .notDetermined {
            snapshot.accessibility = .authorized
        }
        if snapshot.inputMonitoring == .notDetermined {
            snapshot.inputMonitoring = .authorized
        }
    }

    public func setStatus(_ updatedSnapshot: PermissionSnapshot) {
        snapshot = updatedSnapshot
    }
}
