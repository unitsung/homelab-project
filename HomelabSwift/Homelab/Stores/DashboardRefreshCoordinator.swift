import Foundation
import Observation

@MainActor
@Observable
final class DashboardRefreshCoordinator {
    var refreshTrigger = UUID()
    private var timer: Timer?

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
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
