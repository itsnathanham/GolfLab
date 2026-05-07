import SwiftUI

struct LogPracticeSheet: View {
    @Environment(\.dismiss) private var dismiss

    let userId: UUID
    var onLogged: () -> Void = {}

    @State private var sessionDate = Date()
    @State private var practicedRange = false
    @State private var practicedChipping = false
    @State private var practicedPutting = false
    @State private var isSaving = false
    @State private var saveError: String?

    private var anyFocusSelected: Bool {
        practicedRange || practicedChipping || practicedPutting
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Practice day")
                            .font(GLFonts.sans(size: 12, weight: .medium))
                            .foregroundStyle(Color.textSecondary)

                        Text(GLCalendarISO.mmddyyyyDisplay(from: GLCalendarISO.ymd(for: sessionDate)))
                            .font(GLFonts.mono(size: 22, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)

                        DatePicker(
                            "",
                            selection: $sessionDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .accentColor(Color.accent)
                    }
                    .glCardSurface(outlined: true)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Focus")
                            .font(GLFonts.sans(size: 12, weight: .medium))
                            .foregroundStyle(Color.textSecondary)

                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                StatToggle(label: "Range", subtitle: "Full swing reps", isOn: $practicedRange, style: .practice)
                                StatToggle(label: "Chipping", subtitle: "Short game", isOn: $practicedChipping, style: .practice)
                            }
                            StatToggle(label: "Putting", subtitle: "Speed & line work", isOn: $practicedPutting, style: .practice)
                                .frame(maxWidth: .infinity)
                        }
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
                        isEnabled: anyFocusSelected
                    ) {
                        Task { await save() }
                    }
                }
                .padding(.horizontal, GLLayout.horizontalInset)
                .padding(.bottom, 28)
                .padding(.top, 8)
            }
            .background(Color.appBackground)
            .navigationTitle("Log practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.accent)
                }
            }
        }
    }

    @MainActor
    private func save() async {
        guard anyFocusSelected else { return }
        saveError = nil
        isSaving = true
        defer { isSaving = false }

        let ymd = GLCalendarISO.ymd(for: sessionDate)
        let insert = PracticeSessionInsert(
            userId: userId,
            sessionDate: ymd,
            practicedRange: practicedRange,
            practicedChipping: practicedChipping,
            practicedPutting: practicedPutting
        )
        do {
            _ = try await SupabaseService.shared.insertPracticeSession(insert)
            onLogged()
            dismiss()
        } catch {
            saveError = "Couldn’t save. Check your connection, or verify the Supabase migration is installed."
        }
    }
}
