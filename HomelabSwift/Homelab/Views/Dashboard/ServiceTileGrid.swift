import SwiftUI

struct ServiceTileGrid: View {
    @Environment(ServicesStore.self) private var servicesStore
    @Binding var selectedNewServiceType: ServiceType?

    @State private var showAddPicker = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let availableServices = ServiceType.homeServices.filter {
            servicesStore.preferredInstance(for: $0) != nil
        }

        Group {
            if availableServices.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "square.grid.2x2")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    Text("暂无服务")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                    Button {
                        showAddPicker = true
                    } label: {
                        Label("添加服务", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.info)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .glassCard()
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(availableServices, id: \.rawValue) { type in
                        NavigationLink(value: HomeServiceRoute(
                            type: type,
                            instanceId: servicesStore.preferredInstance(for: type)!.id
                        )) {
                            serviceTile(type: type)
                        }
                        .buttonStyle(TilePressButtonStyle())
                    }
                    addTile
                }
            }
        }
        .sheet(isPresented: $showAddPicker) { addServicePickerSheet }
    }

    private func serviceTile(type: ServiceType) -> some View {
        VStack(spacing: 10) {
            ServiceIconView(type: type, size: 30)
                .frame(width: 42, height: 42)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(spacing: 4) {
                Text(type.displayName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Circle()
                        .fill(AppTheme.running)
                        .frame(width: 4, height: 4)
                    Text("在线")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .glassCard()
    }

    private var addTile: some View {
        Button {
            showAddPicker = true
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .foregroundStyle(.tertiary.opacity(0.4))
                        .frame(width: 42, height: 42)

                    Image(systemName: "plus")
                        .font(.headline.weight(.medium))
                        .foregroundStyle(.tertiary)
                }

                Text("添加")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 6)
            .glassCard()
        }
        .buttonStyle(TilePressButtonStyle())
    }

    private var addServicePickerSheet: some View {
        NavigationStack {
            let unconfiguredTypes = ServiceType.homeServices.filter {
                servicesStore.preferredInstance(for: $0) == nil
            }
            if unconfiguredTypes.isEmpty {
                ZStack {
                    AppTheme.background.ignoresSafeArea()
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(AppTheme.running)
                        Text("所有服务已配置")
                            .font(.headline)
                    }
                }
            } else {
                List {
                    Section("选择要添加的服务") {
                        ForEach(unconfiguredTypes, id: \.rawValue) { type in
                            Button {
                                showAddPicker = false
                                selectedNewServiceType = type
                            } label: {
                                HStack(spacing: 12) {
                                    ServiceIconView(type: type, size: 28)
                                        .frame(width: 36, height: 36)
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    Text(type.displayName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(AppTheme.info)
                                        .font(.title3)
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(AppTheme.background)
                .navigationTitle("添加服务")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showAddPicker = false }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct TilePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: configuration.isPressed)
    }
}
