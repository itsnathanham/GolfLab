import SwiftUI

/// Primary control press feedback (docs/design.md — scale 0.97, ~100ms).
struct GLPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Primary / secondary CTAs (`docs/design.md` — Buttons)

/// Full-width primary CTA: accent fill, uppercase label, optional busy state.
struct GLPrimaryCTAButton: View {
    let title: String
    var isBusy: Bool = false
    var busyTitle: String?
    var isEnabled: Bool = true
    var accentFill: Color = .accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isBusy {
                    ProgressView()
                        .tint(.ctaOnAccent)
                }
                Text(isBusy ? (busyTitle ?? title) : title)
                    .font(.glButtonPrimary)
                    .tracking(0.08 * 14)
                    .textCase(.uppercase)
            }
            .foregroundColor(.ctaOnAccent)
            .frame(maxWidth: .infinity)
            .frame(height: GLButtonMetrics.primaryHeight)
            .background(accentFill)
            .clipShape(RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius))
        }
        .buttonStyle(GLPrimaryButtonStyle())
        .disabled(!isEnabled || isBusy)
    }
}

/// Primary CTA with a custom label (e.g. Sign in with Apple icon row).
struct GLPrimaryCTACustomButton<Label: View>: View {
    var isEnabled: Bool = true
    var isBusy: Bool = false
    var accentFill: Color = .accent
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .foregroundColor(.ctaOnAccent)
                .frame(maxWidth: .infinity)
                .frame(height: GLButtonMetrics.primaryHeight)
                .background(accentFill)
                .clipShape(RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius))
        }
        .buttonStyle(GLPrimaryButtonStyle())
        .disabled(!isEnabled || isBusy)
    }
}

/// Ghost secondary: border-default stroke, text-secondary (`design.md`).
struct GLSecondaryGhostButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.glButtonSecondary)
                .foregroundColor(.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: GLButtonMetrics.secondaryHeight)
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                        .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
                )
        }
        .buttonStyle(.plain)
    }
}

