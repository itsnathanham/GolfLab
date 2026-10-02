import SwiftUI
import WatchKit

struct WatchPracticeLogView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: WatchSessionService

    @State private var practicedRange = false
    @State private var practicedChipping = false
    @State private var practicedPutting = false
    @State private var rangeBalls = GLPracticeRangeBalls.defaultCount

    private var sessionDateYMD: String { GLCalendarISO.ymd(for: Date()) }

    private var anyFocusSelected: Bool {
        practicedRange || practicedChipping || practicedPutting
    }

    private var canSave: Bool {
        anyFocusSelected && (!practicedRange || rangeBalls >= GLPracticeRangeBalls.min)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Practice day")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(WatchPalette.textTertiary)
                        .textCase(.uppercase)
                    Text(GLCalendarISO.mmddyyyyDisplay(from: sessionDateYMD))
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(WatchPalette.textPrimary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Focus")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(WatchPalette.textTertiary)
                        .textCase(.uppercase)
                    WatchToggle(label: "Range", isOn: $practicedRange, kind: .practice)
                    WatchToggle(label: "Chipping", isOn: $practicedChipping, kind: .practice)
                    WatchToggle(label: "Putting", isOn: $practicedPutting, kind: .practice)
                }

                if practicedRange {
                    WatchMetricStepper(
                        title: "Range balls",
                        value: $rangeBalls,
                        min: GLPracticeRangeBalls.min,
                        max: 300,
                        step: GLPracticeRangeBalls.step,
                        valuePointSize: 24,
                        buttonSize: 40
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Button {
                    savePractice()
                } label: {
                    Text("Save practice")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(WatchPalette.practice)
                .disabled(!canSave)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(WatchPalette.bg)
        .navigationTitle("Log practice")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.2), value: practicedRange)
    }

    private func savePractice() {
        guard canSave else { return }
        WKInterfaceDevice.current().play(.success)

        let entry = WatchPracticeEntry(
            sessionDate: sessionDateYMD,
            practicedRange: practicedRange,
            practicedChipping: practicedChipping,
            practicedPutting: practicedPutting,
            rangeBallsHit: practicedRange ? rangeBalls : nil
        )
        session.sendPracticeEntry(entry)
        dismiss()
    }
}
