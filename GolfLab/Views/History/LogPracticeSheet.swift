import SwiftUI

struct LogPracticeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var roundStore: RoundStore

    let userId: UUID
    var onLogged: () -> Void = {}

    @State private var sessionDate = Date()
    @State private var practicedRange = false
    @State private var practicedChipping = false
    @State private var practicedPutting = false
    @State private var rangeBalls = GLPracticeRangeBalls.defaultCount
    @State private var isSaving = false
    @State private var saveError: String?

    private var anyFocusSelected: Bool {
        practicedRange || practicedChipping || practicedPutting
    }

    private var canSave: Bool {
        anyFocusSelected && (!practicedRange || rangeBalls >= GLPracticeRangeBalls.min)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topNav
                    .padding(.horizontal, GLLayout.horizontalInset)
                    .padding(.top, GLTopBarMetrics.sheetTopPadding + GLTopBarMetrics.sheetExtraTopInset)
                    .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Practice day")
                            .font(GLFonts.sans(size: 12, weight: .medium))
                            .foregroundStyle(Color.textSecondary)

                        Text(GLCalendarISO.mmddyyyyDisplay(from: GLCalendarISO.ymd(for: sessionDate)))
                            .font(GLFonts.mono(size: 22, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)

                        GLCalendarDatePickerPanel(selectedDate: $sessionDate)
                    }
                    .glCardSurface(outlined: true)

                    HStack(spacing: 8) {
                        StatToggle(label: "Range", isOn: $practicedRange, style: .practice)
                        StatToggle(label: "Chipping", isOn: $practicedChipping, style: .practice)
                        StatToggle(label: "Putting", isOn: $practicedPutting, style: .practice)
                    }

                    if practicedRange {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Range balls")
                                .font(GLFonts.sans(size: 12, weight: .medium))
                                .foregroundStyle(Color.textSecondary)

                            StepperField(
                                label: "balls",
                                value: $rangeBalls,
                                min: GLPracticeRangeBalls.min,
                                max: .max,
                                step: GLPracticeRangeBalls.step
                            )
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if let saveError {
                        Text(saveError)
                            .font(.glFootnote)
                            .foregroundStyle(Color.chartNegativeStrong)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    GLPrimaryCTAButton(
                        title: "Save practice",
                        isBusy: isSaving,
                        busyTitle: "Saving…",
                        isEnabled: canSave
                    ) {
                        Task { await save() }
                    }
                }
                .padding(.horizontal, GLLayout.horizontalInset)
                .padding(.bottom, GLLayout.sheetContentBottomPadding)
            }
        }
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .animation(.easeInOut(duration: 0.2), value: practicedRange)
        .onChange(of: practicedRange) { _, isOn in
            if isOn {
                rangeBalls = PracticeSession.defaultRangeBallsHit(from: roundStore.allPracticeSessions)
            }
        }
    }

    private var topNav: some View {
        HStack {
            GLCircleBackButton { dismiss() }

            Spacer()

            Text("Log practice")
                .font(.glNavTitle)
                .foregroundColor(.textPrimary)

            Spacer()

            Color.clear
                .frame(width: 32, height: 32)
        }
    }

    @MainActor
    private func save() async {
        guard canSave else { return }
        saveError = nil
        isSaving = true
        defer { isSaving = false }

        let ymd = GLCalendarISO.ymd(for: sessionDate)
        let insert = PracticeSessionInsert(
            userId: userId,
            sessionDate: ymd,
            practicedRange: practicedRange,
            practicedChipping: practicedChipping,
            practicedPutting: practicedPutting,
            rangeBallsHit: practicedRange ? rangeBalls : nil
        )
        do {
            let inserted = try await SupabaseService.shared.insertPracticeSession(insert)
            roundStore.upsertPracticeSession(inserted)
            onLogged()
            dismiss()
        } catch {
            saveError = "Couldn’t save. Check your connection, or verify the Supabase migration is installed."
        }
    }
}
