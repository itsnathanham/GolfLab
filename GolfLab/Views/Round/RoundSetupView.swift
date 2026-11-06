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

    /// Name applied from the cache (or home course); keeps the dropdown closed until the user edits the field again.
    @State private var appliedCourseName: String?

    private var courseMatches: [CourseCache.CachedCourse] {
        roundStore.courseCache.coursesMatching(query: courseName)
    }

    @State private var showCoursePickerSheet = false
    
    /// Derived, not stored: the list can only be open while the field has focus and the text is not an applied course.
    private var showsCourseSuggestions: Bool {
        isCourseNameFieldFocused && appliedCourseName != courseName && !courseMatches.isEmpty
    }

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

                VStack(spacing: 0) {
                    courseCard
                    
                    if showsCourseSuggestions {
                        CourseAutocompleteDropdown(matches: courseMatches) { course in
                            selectCourse(course)
                        }
                        .padding(.top, 4)
                    }
                }
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
        .sheet(isPresented: $showCoursePickerSheet) {
            CoursePickerSheet(
                courseCache: roundStore.courseCache,
                selectedName: courseName,
                onSelect: { course in
                    selectCourse(course)
                },
                onNew: {
                    courseName = ""
                    appliedCourseName = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        isCourseNameFieldFocused = true
                    }
                }
            )
        }
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
        .onAppear {
            if holeSetups.isEmpty { buildDefaultHoles() }
        }
        .onChange(of: courseName) { _, newValue in
            if let appliedCourseName, newValue != appliedCourseName {
                self.appliedCourseName = nil
            }
        }
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
            HStack(spacing: 0) {
                courseNameRow
                    .frame(maxWidth: .infinity)
                
                Button {
                    dismissCourseNameKeyboard()
                    showCoursePickerSheet = true
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.textTertiary)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("Saved courses")
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
            divider
            inlineRow(label: "Holes", value: totalHoles == 18 ? "18 holes" : "9 holes") {
                setTotalHoles(totalHoles == 18 ? 9 : 18)
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
        .autocorrectionDisabled()
        .textInputAutocapitalization(.words)
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

    /// Manual 9 ↔ 18 toggle: keep the pars already on the card and pad new holes with par 4.
    private func setTotalHoles(_ count: Int) {
        totalHoles = count
        holeSetups = (1...count).map { holeNumber in
            HoleSetup(holeNumber: holeNumber, par: holeSetups.first { $0.holeNumber == holeNumber }?.par ?? 4)
        }
    }

    private func loadProfile() async {
        guard let userId = AccountService.shared.currentUserId else { return }
        let profile = try? await GolfLabData.store.fetchProfile(userId: userId)
        guard let name = profile?.homeCourseName, !name.isEmpty else { return }
        await MainActor.run {
            guard courseName.isEmpty else { return }
            if let course = roundStore.courseCache.course(named: name) {
                applyCourse(course)
            } else {
                appliedCourseName = name
                courseName = name
            }
        }
    }

    private func startRound() {
        guard !isStartDisabled else { return }
        dismissCourseNameKeyboard()
        isStarting = true
        let trimmedCourseName = courseName.trimmingCharacters(in: .whitespaces)
        let setup = RoundSetup(
            courseName: trimmedCourseName,
            tee: nil,
            totalHoles: totalHoles,
            datePlayed: datePlayed,
            holeSetups: holeSetups
        )
        
        roundStore.courseCache.updateCourseTemplate(
            courseName: trimmedCourseName,
            totalHoles: totalHoles,
            holePars: holeSetups.map(\.par)
        )
        
        Task {
            if let uid = AccountService.shared.currentUserId {
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

    private func selectCourse(_ course: CourseCache.CachedCourse) {
        applyCourse(course)
        dismissCourseNameKeyboard()
    }

    /// Fills name, hole count, and pars from the cached template in one pass. Safe to call repeatedly when the
    /// user switches between courses: every field is replaced, nothing is merged with the previous selection.
    private func applyCourse(_ course: CourseCache.CachedCourse) {
        let holeCount = course.totalHoles > 0 ? course.totalHoles : 18
        appliedCourseName = course.displayName
        courseName = course.displayName
        totalHoles = holeCount
        holeSetups = (1...holeCount).map { holeNumber in
            let index = holeNumber - 1
            let par = course.holePars.indices.contains(index) ? course.holePars[index] : 4
            return HoleSetup(holeNumber: holeNumber, par: par)
        }
    }

}

extension HoleSetup: Identifiable {
    var id: Int { holeNumber }
}

private struct CoursePickerSheet: View {
    @ObservedObject var courseCache: CourseCache
    @Environment(\.dismiss) private var dismiss

    let selectedName: String
    let onSelect: (CourseCache.CachedCourse) -> Void
    let onNew: () -> Void

    private var courses: [CourseCache.CachedCourse] {
        courseCache.courses.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private var selectedKey: String {
        CourseCache.normalizeCourseName(selectedName)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topNav
                    .padding(.horizontal, GLLayout.horizontalInset)
                    .padding(.top, GLTopBarMetrics.sheetTopPadding + GLTopBarMetrics.sheetExtraTopInset)
                    .padding(.bottom, 16)

                Group {
                    if courses.isEmpty {
                        emptyState
                    } else {
                        courseList
                    }
                }
                .padding(.horizontal, GLLayout.horizontalInset)
                .padding(.bottom, GLLayout.sheetContentBottomPadding)
            }
        }
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
    }

    private var topNav: some View {
        GLScreenTopBar(title: "Select course") {
            GLCircleBackButton { dismiss() }
        } trailing: {
            Button {
                onNew()
                dismiss()
            } label: {
                Text("New")
                    .font(GLFonts.sans(size: 16, weight: .semibold))
                    .foregroundColor(.accent)
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("No saved courses yet")
                .font(GLFonts.sans(size: 14, weight: .regular))
                .foregroundColor(.textTertiary)
            Text("Tap New to enter a course name.")
                .font(.glFootnote)
                .foregroundColor(.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var courseList: some View {
        VStack(alignment: .leading, spacing: 8) {
            GLFormFieldLabel(text: "Saved courses")
            VStack(spacing: 0) {
                ForEach(Array(courses.enumerated()), id: \.element.id) { index, course in
                    Button {
                        onSelect(course)
                        dismiss()
                    } label: {
                        HStack(alignment: .center, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(course.displayName)
                                    .font(.glBody)
                                    .foregroundColor(.textPrimary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(course.suggestionSubtitle)
                                    .font(.glFootnote)
                                    .foregroundColor(.textTertiary)
                            }
                            if course.normalizedKey == selectedKey {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.accent)
                            }
                        }
                        .padding(.horizontal, GLCardMetrics.padding)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < courses.count - 1 {
                        Rectangle()
                            .fill(Color.borderDefault)
                            .frame(height: 1)
                    }
                }
            }
            .glCardChromeFrame(outlined: true)
        }
    }
}
