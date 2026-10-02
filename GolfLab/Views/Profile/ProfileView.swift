import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var roundStore: RoundStore
    @State private var profile: UserProfile?
    @State private var displayName = ""
    @State private var weeklyRoundGoal = 1
    @State private var weeklyPracticeGoal = 2
    @State private var stockClubRows: [StockClubYardage] = GLStockClubYardages.defaultBagRows()
    @State private var isSaving = false
    @State private var saveConfirmed = false
    @State private var showSaveErrorAlert = false
    @State private var saveErrorMessage = ""
    @State private var exportURL: URL?
    @State private var showExporter = false
    @State private var isExporting = false
    @State private var showExportError = false
    @State private var stockAutosaveTask: Task<Void, Never>?
    @State private var stockYardagesDirty = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topNav
                    .padding(.horizontal, GLLayout.horizontalInset)
                    .padding(.top, GLTopBarMetrics.sheetTopPadding)
                    .padding(.bottom, GLTopBarMetrics.titleBarBottomSpacing)

                VStack(alignment: .leading, spacing: 22) {
                    GLFormCard {
                        VStack(alignment: .leading, spacing: 16) {
                            GLFormFieldLabel(text: "Account")
                            GLFormTextField(label: "Display name", text: $displayName, prompt: "Your name")
                        }
                    }

                    GLFormCard {
                        VStack(alignment: .leading, spacing: 16) {
                            GLFormFieldLabel(text: "Weekly goals")
                            Text("Targets use your local calendar week. Set a goal to 0 to skip that metric. Raising targets applies from this week forward — past weeks keep the goals that were active then for your streak.")
                                .font(.glFootnote)
                                .foregroundColor(.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Rounds / week")
                                    .font(GLFonts.sans(size: 12, weight: .medium))
                                    .foregroundColor(.textSecondary)
                                StepperField(label: "rounds", value: $weeklyRoundGoal, min: 0, max: 14)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Practices / week")
                                    .font(GLFonts.sans(size: 12, weight: .medium))
                                    .foregroundColor(.textSecondary)
                                StepperField(label: "practices", value: $weeklyPracticeGoal, min: 0, max: 14)
                            }
                        }
                    }

                    StockClubYardagesSection(rows: $stockClubRows) {
                        scheduleStockYardagesAutosave()
                    }

                    GLPrimaryCTAButton(
                        title: saveConfirmed ? "Saved" : "Save changes",
                        isBusy: isSaving,
                        busyTitle: "Saving…",
                        accentFill: saveConfirmed ? Color.accentMid : Color.accent,
                        action: { saveProfile() }
                    )

                    GLSecondaryGhostButton(title: isExporting ? "Exporting…" : "Export data backup") {
                        exportData()
                    }

                    Text("Rounds sync with iCloud on this Apple ID. Stock yardages save as you edit.")
                        .font(.glCaption)
                        .foregroundColor(.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Text("Version")
                            .font(.glCaption)
                            .foregroundColor(.textTertiary)
                        Spacer()
                        Text(Self.appVersionLabel)
                            .font(GLFonts.mono(size: 12, weight: .medium))
                            .foregroundColor(.textTertiary)
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, GLLayout.horizontalInset)
        }
        }
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .tint(.accent)
        .alert("Couldn’t save profile", isPresented: $showSaveErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
        .alert("Couldn’t export data", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        }
        .sheet(isPresented: $showExporter) {
            if let exportURL {
                ActivityView(items: [exportURL])
            }
        }
        .task { await loadProfile() }
        .onDisappear {
            stockAutosaveTask?.cancel()
            stockAutosaveTask = nil
            guard stockYardagesDirty else { return }
            Task { await persistStockClubYardages() }
        }
    }

    private var topNav: some View {
        HStack {
            GLCircleBackButton { dismiss() }
            Spacer()
            Text("Profile")
                .font(.glNavTitle)
                .foregroundColor(.textPrimary)
            Spacer()
            Color.clear
                .frame(width: 32, height: 32)
        }
    }

    private func loadProfile() async {
        guard let userId = AccountService.shared.currentUserId else { return }
        if let p = try? await GolfLabData.store.fetchProfile(userId: userId) {
            await MainActor.run {
                profile = p
                displayName = p.displayName ?? ""
                weeklyRoundGoal = p.weeklyRoundTarget ?? 1
                weeklyPracticeGoal = p.weeklyPracticeTarget ?? 2
                if let saved = p.stockClubYardages {
                    stockClubRows = GLStockClubYardages.sorted(saved)
                } else {
                    stockClubRows = GLStockClubYardages.defaultBagRows()
                }
                roundStore.applyWeeklyGoalState(from: p)
            }
        }
    }

    private func scheduleStockYardagesAutosave() {
        stockYardagesDirty = true
        stockAutosaveTask?.cancel()
        stockAutosaveTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await persistStockClubYardages()
        }
    }

    @MainActor
    private func persistStockClubYardages() async {
        guard stockYardagesDirty else { return }
        guard let userId = AccountService.shared.currentUserId else { return }
        let toSave = GLStockClubYardages.sorted(stockClubRows)
        do {
            let updated = try await GolfLabData.store.updateProfile(
                userId: userId,
                displayName: profile?.displayName,
                homeCourseName: profile?.homeCourseName,
                homeCourseTee: profile?.homeCourseTee,
                preferredUnits: profile?.preferredUnits ?? "yards",
                weeklyRoundTarget: profile?.weeklyRoundTarget,
                weeklyPracticeTarget: profile?.weeklyPracticeTarget,
                weeklyGoalTargetRevisions: nil,
                stockClubYardages: toSave
            )
            profile = updated
            stockYardagesDirty = false
        } catch {
            saveErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showSaveErrorAlert = true
        }
    }

    private func saveProfile() {
        isSaving = true
        stockAutosaveTask?.cancel()
        stockAutosaveTask = nil
        Task {
            guard let userId = AccountService.shared.currentUserId else {
                await MainActor.run { isSaving = false }
                return
            }
            do {
                // Compare against revision-aware “this week” targets so we still PATCH `weekly_goal_target_revisions`
                // when flat columns and jsonb history disagree (Home uses revisions for displayed targets).
                let (effR, effP) = profile.map { $0.effectiveWeeklyTargetsThisWeek() } ?? (1, 2)
                let goalsChanged = weeklyRoundGoal != effR || weeklyPracticeGoal != effP
                let revisionsPatch: [WeeklyGoalTargetRevision]? = goalsChanged
                    ? WeeklyGoalTargetRevision.mergedAfterGoalChange(
                        existing: profile?.weeklyGoalTargetRevisions,
                        savedRoundTarget: effR,
                        savedPracticeTarget: effP,
                        newRound: weeklyRoundGoal,
                        newPractice: weeklyPracticeGoal
                    )
                    : nil

                let stockToSave = GLStockClubYardages.sorted(stockClubRows)

                let updated = try await GolfLabData.store.updateProfile(
                    userId: userId,
                    displayName: displayName.isEmpty ? nil : displayName,
                    homeCourseName: profile?.homeCourseName,
                    homeCourseTee: profile?.homeCourseTee,
                    preferredUnits: "yards",
                    weeklyRoundTarget: weeklyRoundGoal,
                    weeklyPracticeTarget: weeklyPracticeGoal,
                    weeklyGoalTargetRevisions: revisionsPatch,
                    stockClubYardages: stockToSave
                )
                await MainActor.run {
                    profile = updated
                    displayName = updated.displayName ?? ""
                    weeklyRoundGoal = updated.weeklyRoundTarget ?? 1
                    weeklyPracticeGoal = updated.weeklyPracticeTarget ?? 2
                    if let saved = updated.stockClubYardages {
                        stockClubRows = GLStockClubYardages.sorted(saved)
                    }
                    stockYardagesDirty = false
                    roundStore.applyWeeklyGoalState(from: updated)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    isSaving = false
                    saveConfirmed = true
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { saveConfirmed = false }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    showSaveErrorAlert = true
                }
            }
        }
    }

    private func exportData() {
        isExporting = true
        Task {
            defer { Task { @MainActor in isExporting = false } }
            guard let userId = AccountService.shared.currentUserId else {
                await MainActor.run { showExportError = true }
                return
            }
            do {
                let snapshot = try await GolfLabData.store.exportSnapshot(userId: userId)
                let data = try JSONEncoder().encode(snapshot)
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("GolfLab-export.json")
                try data.write(to: url, options: .atomic)
                await MainActor.run {
                    exportURL = url
                    showExporter = true
                }
            } catch {
                await MainActor.run { showExportError = true }
            }
        }
    }

    /// Marketing version + build, e.g. `1.0.1 (2)`, so TestFlight installs are easy to verify.
    private static var appVersionLabel: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0.1"
        let build = info?["CFBundleVersion"] as? String ?? "2"
        return "\(version) (\(build))"
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
