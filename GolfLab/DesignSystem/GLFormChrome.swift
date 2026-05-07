import SwiftUI

// MARK: - Section card (design brief: white card, 1px border, 8pt radius, 14pt padding)

struct GLFormCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(GLCardMetrics.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(GLCardMetrics.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
        )
    }
}

struct GLFormFieldLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.glCaption)
            .foregroundColor(.textTertiary)
            .tracking(0.10 * 12)
    }
}

/// Uppercase caption label above a control block, full width, with bottom spacing.
struct GLSectionFieldHeading: View {
    let text: String

    var body: some View {
        GLFormFieldLabel(text: text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
    }
}

/// Label (Sans caption) + value field on elevated surface (brief: field labels uppercase tertiary).
struct GLFormTextField: View {
    let label: String
    @Binding var text: String
    var prompt: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GLFormFieldLabel(text: label)
            TextField(prompt, text: $text)
                .font(.glBody)
                .foregroundColor(.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(Color.bgElevated)
                .cornerRadius(GLCardMetrics.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                        .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
                )
        }
    }
}

/// Two-option chooser matching filter pill visual language (6pt radius, borders).
struct GLFormBinaryChoice: View {
    let label: String
    @Binding var selection: String
    let optionA: (id: String, title: String)
    let optionB: (id: String, title: String)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GLFormFieldLabel(text: label)
            HStack(spacing: 10) {
                binaryPill(title: optionA.title, isOn: selection == optionA.id) { selection = optionA.id }
                binaryPill(title: optionB.title, isOn: selection == optionB.id) { selection = optionB.id }
            }
        }
    }

    private func binaryPill(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(isOn ? Font.glFilterActive : Font.glFilterInactive)
                .tracking(0.08 * 11)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isOn ? Color.accentDim : Color.clear)
                .foregroundColor(isOn ? Color.accent : Color.textTertiary)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isOn ? Color.borderAccent : Color.borderDefault, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
