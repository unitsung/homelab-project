import Foundation
import Observation

@Observable
final class DashboardSystemStore {
    var systemInfo: BeszelSystemInfo?
    var firstSystemId: String?
    var lastError: String?

    private var refreshTask: Task<Void, Never>?

    func refresh(servicesStore: ServicesStore) async {
        if let existingTask = refreshTask {
            await existingTask.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            guard let instance = servicesStore.preferredInstance(for: .beszel),
                  let client = await servicesStore.beszelClient(instanceId: instance.id) else { return }
            do {
                let response = try await client.getSystems()
                systemInfo = response.items.first?.info
                firstSystemId = response.items.first?.id
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
            refreshTask = nil
        }
        refreshTask = task
        await task.value
    }
}
