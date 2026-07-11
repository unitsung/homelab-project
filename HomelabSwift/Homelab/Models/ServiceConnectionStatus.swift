import Foundation

/// Shared connection lifecycle for service cards and settings.
enum ServiceConnectionStatus: Equatable, Sendable {
    case notConfigured
    case connecting
    case connected(detail: String?)
    case authFailed(message: String?)
    case connectionFailed(message: String?)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}
