import SwiftUI
import Combine

/// Live state for the update progress shell UI.
@MainActor
final class ArcaneUpdateProgressSession: ObservableObject {
    @Published var title: String
    @Published var subtitle: String
    @Published var lines: [String]
    @Published var isRunning: Bool
    @Published var statusText: String?
    @Published var didFail: Bool
    @Published var progressPercent: Int?

    init(
        title: String,
        subtitle: String = "",
        lines: [String] = [],
        isRunning: Bool = true,
        statusText: String? = nil,
        didFail: Bool = false,
        progressPercent: Int? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.lines = lines
        self.isRunning = isRunning
        self.statusText = statusText
        self.didFail = didFail
        self.progressPercent = progressPercent
    }

    func append(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if lines.last != trimmed {
            lines.append(trimmed)
        }
    }

    func replaceLines(with messages: [ArcaneActivityMessage]) {
        guard isRunning else { return }
        let next = messages.map(\.message).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !next.isEmpty {
            lines = next
        }
    }

    func applyActivity(step: String?, progress: Int?, latest: String?) {
        guard isRunning else { return }
        if let progress {
            // Never regress progress (Arcane activity often sticks at early step %).
            let next = max(progressPercent ?? 0, min(99, progress))
            progressPercent = next
        }
        if let step, !step.isEmpty {
            if let p = progressPercent {
                subtitle = "\(step) · \(p)%"
            } else {
                subtitle = step
            }
        } else if let latest, !latest.isEmpty {
            subtitle = latest
        }
    }

    func finish(success: Bool, summary: String) {
        isRunning = false
        didFail = !success
        progressPercent = 100
        statusText = summary
        subtitle = success ? "Completed · 100%" : "Failed · 100%"
        append(summary)
        if success {
            append("# done")
        }
    }
}

/// Terminal-style shell for Arcane update / pull progress (mirrors Arcane Activity Output).
struct ArcaneUpdateProgressSheet: View {
    @ObservedObject var session: ArcaneUpdateProgressSession
    @Environment(\.dismiss) private var dismiss
    @Environment(Localizer.self) private var localizer

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            if session.lines.isEmpty {
                                Text(session.isRunning ? "$ updating…" : "$ no output")
                                    .foregroundStyle(Color.green.opacity(0.7))
                                    .id("empty")
                            } else {
                                ForEach(Array(session.lines.enumerated()), id: \.offset) { index, line in
                                    Text(line)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(lineColor(line))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                        .id(index)
                                }
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(14)
                    }
                    .background(Color.black.opacity(0.92))
                    .onChange(of: session.lines.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }

                if let status = session.statusText, !session.isRunning {
                    Text(status)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(session.didFail ? AppTheme.danger : AppTheme.running)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .glassCard(
                            cornerRadius: 0,
                            tint: (session.didFail ? AppTheme.danger : AppTheme.running).opacity(0.14)
                        )
                }
            }
            .navigationTitle(session.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(session.isRunning ? localizer.t.close : localizer.t.done) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(session.isRunning)
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if session.isRunning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: session.didFail ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(session.didFail ? AppTheme.danger : AppTheme.running)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.subtitle.isEmpty
                         ? (session.isRunning ? localizer.t.loading : localizer.t.done)
                         : session.subtitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(session.isRunning
                         ? localizer.t.arcaneProgressPullHint
                         : (session.didFail ? localizer.t.arcaneProgressWithErrors : localizer.t.arcaneProgressComplete))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textMuted)
                }
                Spacer()
                if let p = session.progressPercent {
                    Text("\(p)%")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(session.isRunning ? AppTheme.warning : (session.didFail ? AppTheme.danger : AppTheme.running))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if let p = session.progressPercent {
                ProgressView(value: Double(p), total: 100)
                    .tint(session.didFail ? AppTheme.danger : arcaneAccent)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .glassCard(cornerRadius: 0, tint: arcaneAccent.opacity(0.1))
    }

    private var arcaneAccent: Color { ServiceType.arcane.colors.primary }

    private func lineColor(_ line: String) -> Color {
        let lower = line.lowercased()
        if lower.contains("fail") || lower.contains("error") {
            return Color.red.opacity(0.9)
        }
        if lower.contains("warn") {
            return Color.orange.opacity(0.9)
        }
        if lower.contains("success") || lower.contains("updated") || lower.contains("complete") {
            return Color.green.opacity(0.9)
        }
        return Color(white: 0.88)
    }
}

// MARK: - Runner

enum ArcaneUpdateProgressRunner {
    /// Runs a long update while polling Arcane activity messages into `session`.
    @MainActor
    static func run(
        session: ArcaneUpdateProgressSession,
        client: ArcaneAPIClient,
        environmentId: String,
        resourceIdHint: String? = nil,
        resourceNameHint: String? = nil,
        operation: @escaping @Sendable () async throws -> ArcaneUpdaterResult
    ) async -> Result<ArcaneUpdaterResult, Error> {
        session.append("$ arcane update")
        if let name = resourceNameHint, !name.isEmpty {
            session.append("# target: \(name)")
        }
        session.append("# waiting for activity stream…")

        let pollTask = Task { @MainActor in
            await pollActivities(
                session: session,
                client: client,
                environmentId: environmentId,
                resourceIdHint: resourceIdHint,
                resourceNameHint: resourceNameHint
            )
        }

        let result: Result<ArcaneUpdaterResult, Error>
        do {
            let value = try await operation()
            result = .success(value)
        } catch {
            result = .failure(error)
        }

        pollTask.cancel()
        // Brief settle so the last activity messages can land before we mark 100%.
        try? await Task.sleep(nanoseconds: 200_000_000)

        switch result {
        case .success(let value):
            if let activityId = value.activityId, !activityId.isEmpty {
                await refreshActivityDetail(
                    session: session,
                    client: client,
                    environmentId: environmentId,
                    activityId: activityId
                )
            }
            let ok = !value.didFail
            session.finish(success: ok, summary: value.userFacingSummary)
        case .failure(let error):
            session.finish(success: false, summary: error.localizedDescription)
        }

        return result
    }

    @MainActor
    private static func pollActivities(
        session: ArcaneUpdateProgressSession,
        client: ArcaneAPIClient,
        environmentId: String,
        resourceIdHint: String?,
        resourceNameHint: String?
    ) async {
        var knownActivityId: String?
        var ticks = 0

        while !Task.isCancelled, session.isRunning {
            ticks += 1
            do {
                if knownActivityId == nil {
                    knownActivityId = try await discoverActivityId(
                        client: client,
                        environmentId: environmentId,
                        resourceIdHint: resourceIdHint,
                        resourceNameHint: resourceNameHint
                    )
                    if let knownActivityId {
                        session.append("# activity \(String(knownActivityId.prefix(8)))…")
                    } else if ticks == 1 || ticks % 5 == 0 {
                        session.append("# still waiting for updater activity…")
                    }
                }

                if let activityId = knownActivityId {
                    let detail = try await client.getActivity(id: activityId, environmentId: environmentId)
                    if let messages = detail.messages, !messages.isEmpty {
                        session.replaceLines(with: messages)
                    } else if let latest = detail.activity.latestMessage, !latest.isEmpty {
                        session.append(latest)
                    }
                    session.applyActivity(
                        step: detail.activity.step,
                        progress: detail.activity.progress,
                        latest: detail.activity.latestMessage
                    )
                    // If activity already terminal while HTTP is still draining, jump progress.
                    if detail.activity.isTerminal {
                        session.applyActivity(step: detail.activity.step ?? "Finishing", progress: 99, latest: detail.activity.latestMessage)
                    }
                }
            } catch {
                // Polling is best-effort; the main update request owns the final error.
            }

            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    private static func discoverActivityId(
        client: ArcaneAPIClient,
        environmentId: String,
        resourceIdHint: String?,
        resourceNameHint: String?
    ) async throws -> String? {
        // Prefer running auto_update activities, then any running activity.
        let running = try await client.listActivities(
            environmentId: environmentId,
            status: "running",
            type: "auto_update",
            limit: 20
        )
        if let match = matchActivity(running, resourceIdHint: resourceIdHint, resourceNameHint: resourceNameHint) {
            return match.id
        }

        let anyRunning = try await client.listActivities(
            environmentId: environmentId,
            status: "running",
            limit: 30
        )
        if let match = matchActivity(anyRunning, resourceIdHint: resourceIdHint, resourceNameHint: resourceNameHint) {
            return match.id
        }

        // Queued is also fine while slot wait is in progress.
        let queued = try await client.listActivities(
            environmentId: environmentId,
            status: "queued",
            type: "auto_update",
            limit: 10
        )
        return matchActivity(queued, resourceIdHint: resourceIdHint, resourceNameHint: resourceNameHint)?.id
    }

    private static func matchActivity(
        _ activities: [ArcaneActivity],
        resourceIdHint: String?,
        resourceNameHint: String?
    ) -> ArcaneActivity? {
        if let resourceIdHint, !resourceIdHint.isEmpty {
            if let hit = activities.first(where: {
                ($0.resourceId ?? "").hasPrefix(resourceIdHint) || resourceIdHint.hasPrefix($0.resourceId ?? "—")
            }) {
                return hit
            }
        }
        if let resourceNameHint, !resourceNameHint.isEmpty {
            let name = resourceNameHint.lowercased()
            if let hit = activities.first(where: {
                ($0.resourceName ?? "").lowercased().contains(name)
                    || ($0.latestMessage ?? "").lowercased().contains(name)
            }) {
                return hit
            }
        }
        return activities.first
    }

    @MainActor
    private static func refreshActivityDetail(
        session: ArcaneUpdateProgressSession,
        client: ArcaneAPIClient,
        environmentId: String,
        activityId: String
    ) async {
        do {
            let detail = try await client.getActivity(id: activityId, environmentId: environmentId)
            if let messages = detail.messages, !messages.isEmpty {
                session.replaceLines(with: messages)
            }
            if let err = detail.activity.error, !err.isEmpty {
                session.append(err)
            }
        } catch {
            // ignore final refresh failures
        }
    }
}
