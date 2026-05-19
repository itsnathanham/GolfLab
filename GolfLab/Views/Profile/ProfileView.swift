import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var roundStore: RoundStore
    @State private var profile: UserProfile?
    @State private var displayName = ""
    @State private var weeklyRoundGoal = 1
    @State private var weeklyPracticeGoal = 2
    @State private var isSaving = false
    @State private var saveConfirmed = false
    @State private var showSignOutAlert = false
    @State private var showSaveErrorAlert = false
    @State private var saveErrorMessage = ""

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

                    GLPrimaryCTAButton(
                        title: saveConfirmed ? "Saved" : "Save changes",
                        isBusy: isSaving,
                        busyTitle: "Saving…",
                        accentFill: saveConfirmed ? Color.accentMid : Color.accent,
                        action: { saveProfile() }
                    )

                    GLSecondaryGhostButton(title: "Sign out") {
                        showSignOutAlert = true
                    }

                    HStack {
                        Text("Version")
                            .font(.glCaption)
                            .foregroundColor(.textTertiary)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
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
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Sign Out", role: .destructive) {
                Task { await authService.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to sign in again to access your data.")
        }
        .alert("Couldn’t save profile", isPresented: $showSaveErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
        .task { await loadProfile() }
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
        guard let userId = await authService.currentUserId else { return }
        if let p = try? await SupabaseService.shared.fetchProfile(userId: userId) {
            await MainActor.run {
                profile = p
                displayName = p.displayName ?? ""
                weeklyRoundGoal = p.weeklyRoundTarget ?? 1
                weeklyPracticeGoal = p.weeklyPracticeTarget ?? 2
                roundStore.applyWeeklyGoalState(from: p)
            }
        }
    }

    private func saveProfile() {
        isSaving = true
        Task {
            guard let userId = await authService.currentUserId else {
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

                let updated = try await SupabaseService.shared.updateProfile(
                    userId: userId,
                    displayName: displayName.isEmpty ? nil : displayName,
                    homeCourseName: profile?.homeCourseName,
                    homeCourseTee: profile?.homeCourseTee,
                    preferredUnits: "yards",
                    weeklyRoundTarget: weeklyRoundGoal,
                    weeklyPracticeTarget: weeklyPracticeGoal,
                    weeklyGoalTargetRevisions: revisionsPatch
                )
                await MainActor.run {
                    profile = updated
                    displayName = updated.displayName ?? ""
                    weeklyRoundGoal = updated.weeklyRoundTarget ?? 1
                    weeklyPracticeGoal = updated.weeklyPracticeTarget ?? 2
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
}
