import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct RoundSetupView: View {
    @EnvironmentObject private var roundStore: RoundStore
    @Environment(\.dismiss) private var dismiss

    @FocusState private var isCourseNameFieldFocused: Bool
    @State private var courseName = ""
    @State private var totalHoles = 18
    @State private var datePlayed = Date()
    @State private var holeSetups: [HoleSetup] = []
    @State private var isStarting = false
    @State private var showDatePickerSheet = false
    @State private var showReplaceActiveRoundAlert = false
    @State private var pendingSetup: RoundSetup?
    @State private var pendingUserId: UUID?

    @State private var userProfile: UserProfile?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topNav
                    .padding(.horizontal, GLLayout.horizontalInset)
                    .padding(.top, 4)
                    .padding(.bottom, 16)

                sectionLabel("Course")
                    .padding(.horizontal, GLLayout.horizontalInset)
                    .padding(.bottom, 8)

                courseCard
                    .padding(.horizontal, GLLayout.horizontalInset)
                    .padding(.bottom, 24)

                photoCTA
                    .padding(.horizontal, GLLayout.horizontalInset)
                    .padding(.bottom, 24)

                sectionLabel("Par")
                    .padding(.horizontal, GLLayout.horizontalInset)
                    .padding(.bottom, 8)

                holeParsCard
                    .padding(.horizontal, GLLayout.horizontalInset)

                Color.clear
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .contentShape(Rectangle())
                    .onTapGesture { dismissCourseNameKeyboard() }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .tint(.accent)
        .sheet(isPresented: $showDatePickerSheet) {
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    Text("Select date")
                        .font(.glNavTitle)
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Button("Done") {
                        showDatePickerSheet = false
                    }
                    .font(GLFonts.sans(size: 16, weight: .semibold))
                    .foregroundColor(.accent)
                }
                .padding(.horizontal, GLLayout.horizontalInset)
                .padding(.vertical, 12)
                .background(Color.cardBackground)

                GLCalendarDatePickerPanel(
                    selectedDate: $datePlayed,
                    maximumDate: Date()
                )
                .padding(.horizontal, GLLayout.horizontalInset)
                .padding(.bottom, 12)

                Spacer(minLength: 0)
            }
            .background(Color.appBackground)
            .preferredColorScheme(.light)
            .presentationDetents([.medium, .large])
        }
        .onAppear { buildDefaultHoles() }
        .onChange(of: totalHoles) { _, _ in buildDefaultHoles() }
        .task { await loadProfile() }
        .alert("Replace in-progress round?", isPresented: $showReplaceActiveRoundAlert) {
            Button("Replace", role: .destructive) {
                if let setup = pendingSetup, let uid = pendingUserId {
                    roundStore.discardActiveRound()
                    roundStore.startRound(setup: setup, userId: uid)
                    finishStartingRound()
                }
                pendingSetup = nil
                pendingUserId = nil
            }
            Button("Cancel", role: .cancel) {
                pendingSetup = nil
                pendingUserId = nil
                isStarting = false
            }
        } message: {
            Text("Starting a new round will discard your current scorecard that hasn't been saved yet.")
        }
    }

    private var isStartDisabled: Bool {
        courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isStarting
    }

    private var topNav: some View {
        HStack {
            GLCircleBackButton {
                dismissCourseNameKeyboard()
                if roundStore.preferNewRoundSetup, !roundStore.allRounds.isEmpty {
                    roundStore.clearPreferNewRoundSetup()
                } else {
                    dismiss()
                }
            }
            .frame(width: 44, alignment: .leading)

            Spacer()

            Text("New Round")
                .font(.glNavTitle)
                .foregroundColor(.textPrimary)

            Spacer()

            Button("Start") {
                startRound()
            }
            .disabled(isStartDisabled)
            .font(GLFonts.sans(size: 16, weight: .semibold))
            .foregroundColor(isStartDisabled ? .textTertiary : .accent)
            .buttonStyle(.plain)
            .frame(width: 44, alignment: .trailing)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.glSubhead)
            .foregroundColor(.textTertiary)
            .tracking(0.04 * 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture { dismissCourseNameKeyboard() }
    }

    private var courseCard: some View {
        VStack(spacing: 0) {
            courseNameRow
            divider
            inlineRow(label: "Holes", value: totalHoles == 18 ? "18 holes" : "9 holes") {
                totalHoles = totalHoles == 18 ? 9 : 18
            }
            divider
            dateRow
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
        )
    }

    private var dateRow: some View {
        Button {
            dismissCourseNameKeyboard()
            showDatePickerSheet = true
        } label: {
            HStack {
                Text("Date")
                    .font(.glBody)
                    .foregroundColor(.textPrimary)
                Spacer()
                Text(formattedLongDate(datePlayed))
                    .font(GLFonts.sans(size: 16, weight: .semibold))
                    .foregroundColor(.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private var photoCTA: some View {
        HStack {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.bgElevated)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "camera")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textTertiary)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Photograph scorecard")
                        .font(.glSubhead)
                        .foregroundColor(.textSecondary)
                    Text("Coming soon - auto-fills pars & yardage")
                        .font(.glFootnote)
                        .foregroundColor(.textTertiary)
                }
            }
            Spacer()
            Text("→")
                .font(GLFonts.sans(size: 14, weight: .regular))
                .foregroundColor(.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.cardBackground)
        .opacity(0.55)
        .clipShape(RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
        )
        .simultaneousGesture(TapGesture().onEnded { dismissCourseNameKeyboard() })
    }

    private var holeParsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(holeSetups.enumerated()), id: \.element.holeNumber) { index, hole in
                holeParRow(holeNumber: hole.holeNumber, par: bindingForPar(holeNumber: hole.holeNumber))
                if index < holeSetups.count - 1 {
                    divider
                }
            }
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
        )
        .simultaneousGesture(TapGesture().onEnded { dismissCourseNameKeyboard() })
    }

    private var courseNameRow: some View {
        TextField(
            "",
            text: $courseName,
            prompt: Text("Course name")
                .foregroundColor(.textSecondary)
        )
        .font(.glBody)
        .foregroundColor(.textPrimary)
        .tint(.accent)
        .focused($isCourseNameFieldFocused)
        .submitLabel(.done)
        .onSubmit { dismissCourseNameKeyboard() }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func dismissCourseNameKeyboard() {
        isCourseNameFieldFocused = false
#if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
    }

    private func inlineRow(label: String, value: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(label)
                .font(.glBody)
                .foregroundColor(.textPrimary)
                .contentShape(Rectangle())
                .onTapGesture { dismissCourseNameKeyboard() }
            Spacer()
            Button {
                dismissCourseNameKeyboard()
                action()
            } label: {
                Text(value)
                    .font(GLFonts.sans(size: 16, weight: .medium))
                    .foregroundColor(.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.borderDefault)
            .frame(height: 1)
    }

    private func holeParRow(holeNumber: Int, par: Binding<Int>) -> some View {
        HStack {
            Text("Hole \(holeNumber)")
                .font(.glBody)
                .foregroundColor(.textPrimary)
            Spacer()
            HStack(spacing: 2) {
                parButton(par: par, value: 3)
                parButton(par: par, value: 4)
                parButton(par: par, value: 5)
            }
            .padding(2)
            .background(Color.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func parButton(par: Binding<Int>, value: Int) -> some View {
        let isActive = par.wrappedValue == value
        return Button {
            dismissCourseNameKeyboard()
            par.wrappedValue = value
        } label: {
            Text("\(value)")
                .font(GLFonts.mono(size: 14, weight: isActive ? .semibold : .medium))
                .foregroundColor(isActive ? .accent : .textTertiary)
                .frame(width: 36, height: 28)
                .background(isActive ? Color.cardBackground : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isActive ? Color.borderAccent : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func bindingForPar(holeNumber: Int) -> Binding<Int> {
        Binding(
            get: {
                holeSetups.first(where: { $0.holeNumber == holeNumber })?.par ?? 4
            },
            set: { newPar in
                if let idx = holeSetups.firstIndex(where: { $0.holeNumber == holeNumber }) {
                    holeSetups[idx].par = newPar
                }
            }
        )
    }

    private func buildDefaultHoles() {
        holeSetups = (1...totalHoles).map { HoleSetup(holeNumber: $0, par: 4) }
    }

    private func loadProfile() async {
        guard let userId = await AuthService.shared.currentUserId else { return }
        userProfile = try? await SupabaseService.shared.fetchProfile(userId: userId)
        if let profile = userProfile {
            await MainActor.run {
                if courseName.isEmpty, let name = profile.homeCourseName { courseName = name }
            }
        }
    }

    private func startRound() {
        guard !isStartDisabled else { return }
        dismissCourseNameKeyboard()
        isStarting = true
        let setup = RoundSetup(
            courseName: courseName.trimmingCharacters(in: .whitespaces),
            tee: nil,
            totalHoles: totalHoles,
            datePlayed: datePlayed,
            holeSetups: holeSetups
        )
        Task {
            if let uid = await AuthService.shared.currentUserId {
                await MainActor.run {
                    if roundStore.isRoundActive {
                        pendingSetup = setup
                        pendingUserId = uid
                        showReplaceActiveRoundAlert = true
                    } else {
                        roundStore.startRound(setup: setup, userId: uid)
                        finishStartingRound()
                    }
                }
            } else {
                await MainActor.run {
                    isStarting = false
                }
            }
        }
    }

    private func finishStartingRound() {
        isStarting = false
        dismiss()
    }

    private func formattedLongDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.calendar = Calendar.current
        df.locale = Locale.current
        df.setLocalizedDateFormatFromTemplate("MMM d, yyyy")
        return df.string(from: date)
    }

}

extension HoleSetup: Identifiable {
    var id: Int { holeNumber }
}
