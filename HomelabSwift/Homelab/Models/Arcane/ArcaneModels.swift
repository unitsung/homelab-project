import Foundation

struct ArcaneContainer: Identifiable, Codable {
    let id: String
    let name: String
    let image: String
    let state: String
    let status: String
    let ports: [ArcanePortMapping]?

    var isRunning: Bool { state == "running" }

    struct ArcanePortMapping: Codable {
        let ip: String?
        let privatePort: Int?
        let publicPort: Int?
        let type: String?

        enum CodingKeys: String, CodingKey {
            case ip = "IP", privatePort = "PrivatePort", publicPort = "PublicPort", type = "Type"
        }
    }
}

struct ArcaneContainerStats: Codable {
    let cpuPercent: Double
    let memoryUsage: Int64
    let memoryLimit: Int64
    let networkRx: Int64
    let networkTx: Int64
}

struct ArcaneContainerDetail: Codable {
    let container: ArcaneContainer
    let stats: ArcaneContainerStats?
    let logs: String?

    struct ContainerModel: Codable {
        let container: ArcaneContainer
    }
}

enum ContainerAction: String, Codable {
    case start, stop, restart, kill, pause, unpause
}
