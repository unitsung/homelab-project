import SwiftUI

struct ServiceEntryCard: View {
    @Environment(ServicesStore.self) private var servicesStore

    var body: some View {
        DashboardCard(title: "服务", icon: "house.fill") {
            let availableServices = ServiceType.homeServices.filter { servicesStore.preferredInstance(for: $0) != nil }
            if availableServices.isEmpty {
                Text("暂无服务")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.vertical, 16)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 12) {
                    ForEach(availableServices, id: \.rawValue) { type in
                        NavigationLink(value: HomeServiceRoute(type: type, instanceId: servicesStore.preferredInstance(for: type)!.id)) {
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
