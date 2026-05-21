import SwiftUI
import UIKit

struct EndRoundView: View {
    @EnvironmentObject private var roundStore: RoundStore
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var active: ActiveRound? { roundStore.activeRound }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let round = active {
                    VStack(spacing: 0) {
                        endRoundTopNav
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.top, GLTopBarMetrics.sheetTopPadding + GLTopBarMetrics.sheetExtraTopInset)
                            .padding(.bottom, GLTopBarMetrics.titleBarBottomSpacing)

                        endRoundHeaderCard(round: round)
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.bottom, 16)

                        endRoundStatGrid(round: round)
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.bottom, 16)

                        RoundVsParProgressCard(
                            savedHoles: savedHoles(round),
                            totalHoles: round.setup.totalHoles
                        )
                        .padding(.horizontal, GLLayout.horizontalInset)
                        .padding(.bottom, 16)

                        if incompleteSavedScorecard(round) {
                            Text("This round has \(savedHoles(round).count) of \(round.setup.totalHoles) hole records saved. The figures above sum only those holes.")
                                .font(.glCaption)
                                .foregroundColor(.textTertiary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, GLLayout.horizontalInset)
                                .padding(.bottom, 12)
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.glSubhead)
                                .foregroundColor(.chartNegativeStrong)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, GLLayout.horizontalInset)
                                .padding(.bottom, 8)
                        }

                        endRoundCtas
                            .padding(.horizontal, GLLayout.horizontalInset)
                            .padding(.bottom, GLLayout.sheetContentBottomPadding)
                    }
                }
            }
            .background(Color.appBackground)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                roundStore.mergePendingWatchHoleEntries()
                roundStore.persistUnsavedCurrentHoleIfEligible()
            }
        }
    }

    private var endRoundTopNav: some View {
        HStack {
            GLCircleBackButton { dismiss() }

            Spacer()

            Text("End round")
                .font(.glNavTitle)
                .foregroundColor(.textPrimary)

            Spacer()

            Color.clear
                .frame(width: 32, height: 32)
        }
    }

    // MARK: - Header card (matches `LastRoundSummaryView.roundHeader`)

    private func endRoundHeaderCard(round: ActiveRound) -> some View {
        let vs = vsParHeadlineFromActive(round)
        let totals = round.computedTotals
        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(round.setup.courseName)
                    .font(GLFonts.sans(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(endRoundMetaLine(round))
                    .font(.glFootnote)
                    .foregroundColor(.textTertiary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(vs.text)
                    .font(GLFonts.mono(size: 28, weight: .semibold))
                    .foregroundColor(vs.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Text("\(totals.score) total")
                    .font(GLFonts.mono(size: 12, weight: .medium))
                    .foregroundColor(.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
        )
    }

    // MARK: - Stat grid

    private func endRoundStatGrid(round: ActiveRound) -> some View {
        let saved = savedHoles(round)
        let n = max(saved.count, 1)
        let totals = round.computedTotals
        let parSum = saved.reduce(0) { $0 + $1.par }

        let scoreVsPar: Double? = saved.isEmpty ? nil : Double(totals.score - parSum)
        let girPct: Double = saved.isEmpty ? 0 : Double(totals.gir) / Double(saved.count) * 100
        let firPct: Double = {
            guard !saved.isEmpty else { return 0 }
            let elig = saved.filter { $0.par > 3 }.count
            guard elig > 0 else { return 0 }
            return Double(saved.filter { $0.par > 3 && $0.fir == true }.count) / Double(elig) * 100
        }()
        let pph: Double = saved.isEmpty ? 0 : Double(totals.putts) / Double(saved.count)

        return GLStatFourUpSummaryGrid(
            scoreLabel: "Score vs par",
            scoreValue: scoreVsPar.map(formatVsPar) ?? "—",
            scoreUsesAccent: scoreVsPar != nil,
            firValue: saved.isEmpty ? "—" : String(format: "%.0f", firPct),
            girValue: saved.isEmpty ? "—" : String(format: "%.0f", girPct),
            puttsValue: saved.isEmpty ? "—" : String(format: "%.1f", pph),
            accessibilityLabel: "Round stats over \(n) saved holes"
        )
    }

    private var endRoundCtas: some View {
        GLPrimaryCTAButton(
            title: "Save round",
            isBusy: isSaving,
            busyTitle: "Saving…",
            action: { saveRound() }
        )
    }

    // MARK: - Actions

    private func saveRound() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                _ = try await roundStore.saveRoundToSupabase()
                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                    roundStore.presentPendingWeeklyGoalCelebrationIfNeeded()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
            await MainActor.run { isSaving = false }
        }
    }

    // MARK: - Helpers

    private func savedHoles(_ round: ActiveRound) -> [ActiveHole] {
        round.holes.filter(\.isSaved)
    }

    private func incompleteSavedScorecard(_ round: ActiveRound) -> Bool {
        !savedHoles(round).isEmpty && savedHoles(round).count < round.setup.totalHoles
    }

    private func endRoundMetaLine(_ round: ActiveRound) -> String {
        let date = round.setup.datePlayed
        let saved = savedHoles(round).count
        let total = round.setup.totalHoles
        let holesFragment: String
        if saved == total {
            holesFragment = "\(total) hole\(total == 1 ? "" : "s")"
        } else {
            holesFragment = "\(saved) of \(total) holes saved"
        }
        if Calendar.current.isDateInToday(date) {
            return "Today · \(holesFragment)"
        }
        let df = DateFormatter()
        df.calendar = Calendar.current
        df.locale = Locale.current
        df.setLocalizedDateFormatFromTemplate("MMM d")
        return "\(df.string(from: date)) · \(holesFragment)"
    }

    private func vsParHeadlineFromActive(_ round: ActiveRound) -> (text: String, color: Color) {
        let saved = savedHoles(round)
        guard !saved.isEmpty else { return ("--", .textTertiary) }
        let totals = round.computedTotals
        let par = saved.reduce(0) { $0 + $1.par }
        guard par > 0 else { return ("--", .textTertiary) }
        let delta = Double(totals.score - par)
        let text = formatVsPar(delta)
        return (text, Color.accent)
    }

    private func formatVsPar(_ value: Double) -> String {
        if value == 0 { return "E" }
        if abs(value.rounded() - value) < 0.01 {
            let raw = String(format: "%+.0f", value)
            return raw.replacingOccurrences(of: "-", with: "\u{2212}")
        }
        let raw = String(format: "%+.1f", value)
        return raw.replacingOccurrences(of: "-", with: "\u{2212}")
    }
}
