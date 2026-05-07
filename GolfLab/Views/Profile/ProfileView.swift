import SwiftUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var profile: UserProfile?
    @State private var displayName = ""
    @State private var preferredUnits = "yards"
    @State private var isSaving = false
    @State private var saveConfirmed = false
    @State private var showSignOutAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                GLFormCard {
                    VStack(alignment: .leading, spacing: 16) {
                        GLFormFieldLabel(text: "Account")
                        GLFormTextField(label: "Display name", text: $displayName, prompt: "Your name")
                    }
                }

                GLFormCard {
                    GLFormBinaryChoice(
                        label: "Distance units",
                        selection: $preferredUnits,
                        optionA: ("yards", "Yards"),
                        optionB: ("metres", "Metres")
                    )
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
                .padding(.top, 4)
            }
            .padding(.horizontal, GLLayout.horizontalInset)
            .padding(.vertical, 20)
        }
        .background(Color.bgPrimary)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .tint(.accent)
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Sign Out", role: .destructive) {
                Task { await authService.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to sign in again to access your data.")
        }
        .task { await loadProfile() }
    }

    private func loadProfile() async {
        guard let userId = await authService.currentUserId else { return }
        if let p = try? await SupabaseService.shared.fetchProfile(userId: userId) {
            await MainActor.run {
                profile = p
                displayName = p.displayName ?? ""
                preferredUnits = p.preferredUnits
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
                try await SupabaseService.shared.updateProfile(
                    userId: userId,
                    displayName: displayName.isEmpty ? nil : displayName,
                    homeCourseName: profile?.homeCourseName,
                    homeCourseTee: profile?.homeCourseTee,
                    preferredUnits: preferredUnits
                )
                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    isSaving = false
                    saveConfirmed = true
                }
                await loadProfile()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { saveConfirmed = false }
            } catch {
                await MainActor.run { isSaving = false }
            }
        }
    }
}
