import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ICloudRequiredView: View {
    var message: String?
    var onRetry: () async -> Void

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "icloud")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundColor(.accent)
                Text("iCloud required")
                    .font(.glDisplay)
                    .foregroundColor(.textPrimary)
                Text(message ?? "Sign in to iCloud in Settings to keep Golf Lab synced across your devices.")
                    .font(.glBody)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, GLLayout.horizontalInset)
                Spacer()
                GLPrimaryCTACustomButton(
                    isEnabled: true,
                    isBusy: false,
                    action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    },
                    label: {
                        Text("Open Settings")
                            .font(.glButtonPrimary)
                            .tracking(0.08 * 14)
                            .textCase(.uppercase)
                    }
                )
                .padding(.horizontal, GLLayout.horizontalInset)
                Button("Try again") {
                    Task { await onRetry() }
                }
                .font(.glSubhead)
                .foregroundColor(.textSecondary)
                .padding(.bottom, 48)
            }
        }
    }
}

struct MigrationProgressView: View {
    let detail: String

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .tint(.accent)
                Text("Checking iCloud")
                    .font(.glNavTitle)
                    .foregroundColor(.textPrimary)
                Text(detail)
                    .font(.glBody)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, GLLayout.horizontalInset)
            }
        }
    }
}

struct MigrationFailedView: View {
    let message: String
    var onRetry: () async -> Void
    var onImport: (Data) -> Void
    var onContinueEmpty: () async -> Void

    @State private var showImporter = false
    @State private var showContinueConfirm = false

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(.chartNegativeStrong)
                Text("Couldn’t load rounds")
                    .font(.glDisplay)
                    .foregroundColor(.textPrimary)
                Text(message)
                    .font(.glBody)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, GLLayout.horizontalInset)
                Text("If you just installed, wait a few seconds for iCloud. You can also import a JSON backup from Profile.")
                    .font(.glCaption)
                    .foregroundColor(.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, GLLayout.horizontalInset)
                Spacer()
                GLPrimaryCTACustomButton(
                    isEnabled: true,
                    isBusy: false,
                    action: { Task { await onRetry() } },
                    label: {
                        Text("Try again")
                            .font(.glButtonPrimary)
                            .tracking(0.08 * 14)
                            .textCase(.uppercase)
                    }
                )
                .padding(.horizontal, GLLayout.horizontalInset)
                Button("Import JSON export") {
                    showImporter = true
                }
                .font(.glSubhead)
                .foregroundColor(.accent)
                Button("Continue without importing") {
                    showContinueConfirm = true
                }
                .font(.glCaption)
                .foregroundColor(.textTertiary)
                .padding(.bottom, 48)
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url) {
                onImport(data)
            }
        }
        .alert("Start with empty history?", isPresented: $showContinueConfirm) {
            Button("Start empty", role: .destructive) {
                Task { await onContinueEmpty() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This phone will start with empty history. Existing iCloud data may still arrive later. You can import a JSON backup from Profile.")
        }
    }
}
