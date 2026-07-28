import Foundation
import Observation

@MainActor
@Observable
final class DashboardRefreshCoordinator {
    var refreshTrigger = UUID()
    private var timer: Timer?

    func start() {
        stop()
        refreshTrigger = UUID()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshTrigger = UUID()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
