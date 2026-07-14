import SwiftUI

struct ServiceEntryCard: View {
    @Environment(ServicesStore.self) private var servicesStore

    var body: some View {
        DashboardCard(title: "服务", icon: "house.fill") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 12) {
                ForEach(ServiceType.homeServices, id: \.rawValue) { type in
                    if let instance = servicesStore.preferredInstance(for: type) {
                        NavigationLink(value: HomeServiceRoute(type: type, instanceId: instance.id)) {
                            VStack(spacing: 6) {
                                ServiceIconView(type: type, size: 28)
                                    .frame(width: 44, height: 44)
                                    .background(type.colors.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                Text(type.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
