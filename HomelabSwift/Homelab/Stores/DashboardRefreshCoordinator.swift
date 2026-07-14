import Foundation
import Observation

@Observable
final class DashboardRefreshCoordinator {
    var refreshTrigger = UUID()
    private(set) var isRefreshing = false
    private var timer: Timer?

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isRefreshing = true
                self?.refreshTrigger = UUID()
                self?.isRefreshing = false
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRefreshing = false
    }
}
