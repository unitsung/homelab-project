import Foundation

/// Bulk-replace the host component of service base URLs while keeping scheme, port, and path.
enum ServiceHostBulkReplacer {
    enum Scope: String, CaseIterable, Identifiable {
        case primary
        case fallback
        case both

        var id: String { rawValue }
    }

    struct PreviewRow: Identifiable, Equatable {
        let id: UUID
        let label: String
        let type: ServiceType
        let oldPrimary: String
        let newPrimary: String
        let oldFallback: String?
        let newFallback: String?
        let primaryChanged: Bool
        let fallbackChanged: Bool

        var hasChanges: Bool { primaryChanged || fallbackChanged }
    }

    /// Accepts a bare host, or a pasted URL — returns hostname only (no port / path / scheme).
    static func normalizeHostInput(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }

        if s.contains("://"), let comps = URLComponents(string: s), let host = comps.host, !host.isEmpty {
            return host
        }

        // user:pass@host:port/path → host
        if let at = s.lastIndex(of: "@") {
            s = String(s[s.index(after: at)...])
        }
        if let slash = s.firstIndex(of: "/") {
            s = String(s[..<slash])
        }
        // Strip :port (IPv6 in brackets left alone if present).
        if s.hasPrefix("["), let end = s.firstIndex(of: "]") {
            s = String(s[s.startIndex...end]).trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        } else if let colon = s.lastIndex(of: ":") {
            let after = s[s.index(after: colon)...]
            if !after.isEmpty, after.allSatisfy(\.isNumber) {
                s = String(s[..<colon])
            }
        }

        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidHost(s) else { return nil }
        return s
    }

    static func isValidHost(_ host: String) -> Bool {
        guard !host.isEmpty,
              !host.contains(" "),
              !host.contains("/"),
              !host.contains("://"),
              host.count <= 253
        else { return false }

        // IPv4
        let ipv4 = #"^((25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(25[0-5]|2[0-4]\d|[01]?\d\d?)$"#
        if host.range(of: ipv4, options: .regularExpression) != nil { return true }

        // Hostname / mDNS / Tailscale magicDNS (labels with letters, digits, hyphen; dots allowed)
        let name = #"^(?=.{1,253}$)([A-Za-z0-9]([A-Za-z0-9\-]{0,61}[A-Za-z0-9])?)(\.([A-Za-z0-9]([A-Za-z0-9\-]{0,61}[A-Za-z0-9])?))*\.?$"#
        if host.range(of: name, options: .regularExpression) != nil { return true }

        // Simple IPv6 (compressed forms)
        let ipv6 = #"^[0-9A-Fa-f:]+$"#
        if host.contains(":"), host.range(of: ipv6, options: .regularExpression) != nil {
            return true
        }
        return false
    }

    /// Replace only the host of `rawURL`. Returns nil if the URL cannot be parsed.
    /// Unchanged host (case-insensitive) still returns the original string.
    static func replaceHost(in rawURL: String, with newHost: String) -> String? {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var comps = URLComponents(string: trimmed)
        if comps?.host == nil || comps?.scheme == nil {
            // Relative / scheme-less values stored by some services.
            comps = URLComponents(string: trimmed.contains("://") ? trimmed : "https://\(trimmed)")
        }
        guard var components = comps, let oldHost = components.host, !oldHost.isEmpty else {
            return nil
        }
        if oldHost.caseInsensitiveCompare(newHost) == .orderedSame {
            return trimmed
        }
        components.host = newHost
        return components.string
    }

    static func preview(
        instances: [ServiceInstance],
        newHost: String,
        scope: Scope
    ) -> [PreviewRow] {
        instances.compactMap { instance in
            var newPrimary = instance.url
            var newFallback = instance.fallbackUrl
            var primaryChanged = false
            var fallbackChanged = false

            if scope == .primary || scope == .both {
                if let replaced = replaceHost(in: instance.url, with: newHost) {
                    primaryChanged = replaced != instance.url
                    newPrimary = replaced
                }
            }
            if scope == .fallback || scope == .both, let fb = instance.fallbackUrl, !fb.isEmpty {
                if let replaced = replaceHost(in: fb, with: newHost) {
                    fallbackChanged = replaced != fb
                    newFallback = replaced
                }
            }

            guard primaryChanged || fallbackChanged else { return nil }
            return PreviewRow(
                id: instance.id,
                label: instance.displayLabel,
                type: instance.type,
                oldPrimary: instance.url,
                newPrimary: newPrimary,
                oldFallback: instance.fallbackUrl,
                newFallback: newFallback,
                primaryChanged: primaryChanged,
                fallbackChanged: fallbackChanged
            )
        }
    }
}
