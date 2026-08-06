import SwiftUI

// MARK: - GlassCard
// Native iOS 26 replacement for LiquidGlass.tsx GlassCard.
// Uses the real .glassEffect() modifier.
// Deployment target is iOS 26 — no fallback needed.

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = AppTheme.cardRadius
    var tint: Color? = nil
    var interactive: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(AppTheme.innerPadding)
            .modifier(GlassEffectModifier(
                cornerRadius: cornerRadius,
                tint: tint,
                interactive: interactive
            ))
    }
}

// MARK: - GlassEffectModifier

struct GlassEffectModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    let interactive: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        var glass = Glass.regular
        if let tint {
            glass = glass.tint(tint)
        }
        if interactive {
            glass = glass.interactive()
        }
        return content
            .glassEffect(glass, in: shape)
    }
}

// MARK: - GlassGroupContainer
// Wraps GlassEffectContainer for morphing and shared sampling.

struct GlassGroup<Content: View>: View {
    var spacing: CGFloat? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        GlassEffectContainer(spacing: spacing) {
            content()
        }
    }
}

// MARK: - Convenience modifiers

extension View {
    func glassCard(cornerRadius: CGFloat = AppTheme.cardRadius, tint: Color? = nil) -> some View {
        self.modifier(GlassEffectModifier(cornerRadius: cornerRadius, tint: tint, interactive: false))
    }

    /// Selected → glassProminent; unselected → glass. Shared by filter / chip bars.
    @ViewBuilder
    func glassChipStyle(selected: Bool, tint: Color) -> some View {
        if selected {
            self.buttonStyle(.glassProminent).tint(tint).controlSize(.small)
        } else {
            self.buttonStyle(.glass).tint(tint).controlSize(.small)
        }
    }
}

// NOTE: .buttonStyle(.glass) and .buttonStyle(.glassProminent)
// are native iOS 26 ButtonStyles — no custom definitions needed.
