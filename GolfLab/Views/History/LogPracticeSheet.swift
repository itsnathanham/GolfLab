import SwiftUI

struct LogPracticeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var roundStore: RoundStore

    let userId: UUID
    let onLogged: () -> Void
    private let existing: PracticeSession?

    @State private var sessionDate: Date
    @State private var practicedRange: Bool
    @State private var practicedChipping: Bool
    @State private var practicedPutting: Bool
    @State private var rangeBalls: Int
    @State private var isSaving: Bool
    @State private var isDeleting: Bool
    @State private var saveError: String?
    @State private var showDeleteConfirm: Bool

    init(userId: UUID, existing: PracticeSession? = nil, onLogged: @escaping () -> Void = {}) {
        self.userId = userId
        self.existing = existing
        self.onLogged = onLogged
        let start = existing.flatMap { GLCalendarISO.date(fromYMD: $0.sessionDate) } ?? Date()
        _sessionDate = State(initialValue: start)
        _practicedRange = State(initialValue: existing?.practicedRange ?? false)
        _practicedChipping = State(initialValue: existing?.practicedChipping ?? false)
        _practicedPutting = State(initialValue: existing?.practicedPutting ?? false)
        _rangeBalls = State(initialValue: existing?.loggedRangeBallsHit ?? GLPracticeRangeBalls.defaultCount)
        _isSaving = State(initialValue: false)
        _isDeleting = State(initialValue: false)
        _saveError = State(initialValue: nil)
        _showDeleteConfirm = State(initialValue: false)
    }

    private var anyFocusSelected: Bool {
        practicedRange || practicedChipping || practicedPutting
    }

    private var canSave: Bool {
        anyFocusSelected && (!practicedRange || rangeBalls >= GLPracticeRangeBalls.min)
    }

    private var isEditing: Bool { existing != nil }

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
                        title: isEditing ? "Save changes" : "Save practice",
                        isBusy: isSaving,
                        busyTitle: "Saving…",
                        isEnabled: canSave && !isDeleting
                    ) {
                        Task { await save() }
                    }

                    if isEditing {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Text(isDeleting ? "Deleting…" : "Delete practice")
                                .font(.glButtonSecondary)
                                .foregroundColor(.chartNegative)
                                .frame(maxWidth: .infinity)
                                .frame(height: GLButtonMetrics.secondaryHeight)
                                .background(Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius))
                                .overlay(
                                    RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                                        .stroke(Color.chartNegative.opacity(0.45), lineWidth: GLCardMetrics.strokeWidth)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaving || isDeleting)
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
            guard isOn, existing?.loggedRangeBallsHit == nil else { return }
            rangeBalls = PracticeSession.defaultRangeBallsHit(from: roundStore.allPracticeSessions)
        }
        .alert("Delete practice?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task { await deleteSession() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteMessage)
        }
    }

    private var topNav: some View {
        HStack {
            GLCircleBackButton { dismiss() }

            Spacer()

            Text(isEditing ? "Edit practice" : "Log practice")
                .font(.glNavTitle)
                .foregroundColor(.textPrimary)

            Spacer()

            Color.clear
                .frame(width: 32, height: 32)
        }
    }

    private var deleteMessage: String {
        let named: String
        if let label = existing?.focusSubtitle, !label.isEmpty {
            named = label
        } else {
            named = "this practice session"
        }
        let day = GLCalendarISO.mmddyyyyDisplay(from: existing?.sessionDate ?? GLCalendarISO.ymd(for: sessionDate))
        return "This permanently deletes \(named) on \(day). Weekly goals recount from the sessions that remain."
    }

    @MainActor
    private func save() async {
        guard canSave, !isSaving, !isDeleting else { return }
        saveError = nil
        isSaving = true
        defer { isSaving = false }

        let ymd = GLCalendarISO.ymd(for: sessionDate)
        let balls = practicedRange ? rangeBalls : nil
        do {
            let saved: PracticeSession
            if let existing {
                saved = try await GolfLabData.store.updatePracticeSession(
                    id: existing.id,
                    sessionDate: ymd,
                    practicedRange: practicedRange,
                    practicedChipping: practicedChipping,
                    practicedPutting: practicedPutting,
                    rangeBallsHit: balls
                )
            } else {
                let insert = PracticeSessionInsert(
                    userId: userId,
                    sessionDate: ymd,
                    practicedRange: practicedRange,
                    practicedChipping: practicedChipping,
                    practicedPutting: practicedPutting,
                    rangeBallsHit: balls
                )
                saved = try await GolfLabData.store.insertPracticeSession(insert)
            }
            roundStore.upsertPracticeSession(saved)
            onLogged()
            dismiss()
        } catch {
            saveError = "Couldn’t save. Check iCloud, then try again."
        }
    }

    @MainActor
    private func deleteSession() async {
        guard let existing, !isSaving, !isDeleting else { return }
        saveError = nil
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await GolfLabData.store.deletePracticeSession(id: existing.id)
            roundStore.removePracticeSession(id: existing.id)
            dismiss()
        } catch {
            saveError = "Couldn’t delete. Check iCloud, then try again."
        }
    }
}

/// Day summary and week summary practice rows. Tap opens edit.
struct PracticeSessionCardList: View {
    @EnvironmentObject private var roundStore: RoundStore

    let sessions: [PracticeSession]

    @State private var sessionToEdit: PracticeSession?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                Button {
                    sessionToEdit = session
                } label: {
                    PracticeSessionRowView(session: session)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(PracticeSessionRowView.accessibilityLabel(for: session))
                .accessibilityHint("Opens edit practice")
                if index < sessions.count - 1 {
                    Rectangle()
                        .fill(Color.borderDefault)
                        .frame(height: 1)
                }
            }
        }
        .glCardChromeFrame(outlined: true)
        .sheet(item: $sessionToEdit) { session in
            LogPracticeSheet(userId: session.userId, existing: session)
                .presentationDragIndicator(.visible)
                .environmentObject(roundStore)
        }
    }
}

/// Practice list row: focus, relative day, ball count, chevron. Matches `RoundListRowView` density.
struct PracticeSessionRowView: View {
    let session: PracticeSession

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Circle()
                .fill(Color.calendarPracticeDot)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 3) {
                Text(session.focusTitle)
                    .font(.glSubhead)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                Text(Self.metaLine(for: session))
                    .font(.glFootnote)
                    .foregroundColor(.textTertiary)
            }
            Spacer(minLength: 8)
            HStack(alignment: .center, spacing: 10) {
                if let balls = session.loggedRangeBallsHit {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(balls)")
                            .font(GLFonts.mono(size: 17, weight: .semibold))
                            .foregroundColor(.calendarPracticeDot)
                        Text("balls")
                            .font(GLFonts.mono(size: 12, weight: .medium))
                            .foregroundColor(.textTertiary)
                    }
                }
                Text("›")
                    .font(GLFonts.sans(size: 14, weight: .regular))
                    .foregroundColor(.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    static func accessibilityLabel(for session: PracticeSession) -> String {
        var parts = [session.focusTitle, metaLine(for: session)]
        if let balls = session.loggedRangeBallsHit {
            parts.append("\(balls) balls")
        }
        return parts.joined(separator: ", ")
    }

    static func metaLine(for session: PracticeSession) -> String {
        guard let date = GLCalendarISO.date(fromYMD: session.sessionDate) else {
            return GLCalendarISO.mmddyyyyDisplay(from: session.sessionDate)
        }
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter.string(from: date)
    }
}
