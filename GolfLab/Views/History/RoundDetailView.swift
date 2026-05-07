import SwiftUI

struct RoundDetailView: View {
    let round: Round
    @EnvironmentObject private var roundStore: RoundStore
    @Environment(\.dismiss) private var dismiss
    @State private var holes: [Hole] = []
    @State private var isLoading = true
    @State private var showDeleteAlert = false
    @State private var displayedCourseName: String
    @State private var showCourseNameEditor = false
    @State private var courseNameDraft = ""
    @State private var courseNameSaveError: String?
    @State private var isSavingCourseName = false

    init(round: Round) {
        self.round = round
        _displayedCourseName = State(initialValue: round.courseName)
    }
    
    private var tableLayout: RoundDetailTableLayout {
        // Table content width = screen width - outer page insets - table inner horizontal padding.
        let screenWidth = UIScreen.main.bounds.width
        let contentWidth = max(220, screenWidth - (GLLayout.horizontalInset * 2) - 24)
        return RoundDetailTableLayout.fitted(for: contentWidth)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topNav
                    .padding(.horizontal, GLLayout.horizontalInset)
                    .padding(.top, 4)
                    .padding(.bottom, 16)

                if isLoading {
                    detailLoadingState
                        .padding(.horizontal, GLLayout.horizontalInset)
                } else {
                    roundSummaryHeader
                        .padding(.horizontal, GLLayout.horizontalInset)
                        .padding(.bottom, 20)

                    scorecardTable
                        .padding(.horizontal, GLLayout.horizontalInset)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Delete Round?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    try? await SupabaseService.shared.deleteRound(id: round.id)
                    await roundStore.loadRounds()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this round and all its hole data. This cannot be undone.")
        }
        .sheet(isPresented: $showCourseNameEditor) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    TextField(
                        "",
                        text: $courseNameDraft,
                        prompt: Text("Course name")
                            .foregroundColor(.textSecondary)
                    )
                    .font(.glBody)
                    .foregroundColor(.textPrimary)
                    .tint(.accent)
                    .padding(12)
                    .background(Color.bgElevated)
                    .cornerRadius(GLCardMetrics.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                            .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
                    )

                    if let courseNameSaveError {
                        Text(courseNameSaveError)
                            .font(.glFootnote)
                            .foregroundColor(.chartNegativeStrong)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, GLLayout.horizontalInset)
                .padding(.top, 16)
                .background(Color.bgPrimary)
                .navigationTitle("Course name")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showCourseNameEditor = false
                            courseNameSaveError = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task { await saveCourseNameEdit() }
                        }
                        .disabled(
                            courseNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || isSavingCourseName
                        )
                    }
                }
            }
        }
        .task { await loadHoles() }
    }

    private var topNav: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Color.cardBackground)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.borderDefault, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Round detail")
                .font(.glNavTitle)
                .foregroundColor(.textPrimary)

            Spacer()

            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.chartNegative)
                    .frame(width: 32, height: 32)
                    .background(Color.chartNegativeFill.opacity(0.8))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.chartNegative.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var tableTotals: HoleAggregatedTotals {
        guard !holes.isEmpty else {
            return HoleAggregatedTotals(
                score: round.totalScore ?? 0,
                putts: round.totalPutts ?? 0,
                gir: round.totalGir ?? 0,
                fir: round.totalFir ?? 0,
                penalties: 0
            )
        }
        return holes.aggregatedRoundTotals
    }

    private var headerTotalScore: Int? {
        if !holes.isEmpty { return tableTotals.score }
        return round.totalScore
    }

    private var headerParTotal: Int? {
        if !holes.isEmpty { return holes.totalParFromHoles }
        return roundStore.totalParSumByRoundId[round.id]
    }

    private var roundMetaLine: String {
        let holesPart = "\(round.holes) holes"
        guard let date = Self.ymdDate(round.datePlayed) else {
            return "\(round.datePlayedDisplay) · \(holesPart)"
        }
        let df = DateFormatter()
        df.calendar = Calendar.current
        df.locale = Locale.current
        df.setLocalizedDateFormatFromTemplate("MMM d")
        return "\(df.string(from: date)) · \(holesPart)"
    }

    private var headlineVsPar: (text: String, color: Color) {
        guard let score = headerTotalScore,
              let par = headerParTotal,
              par > 0
        else { return ("—", .textTertiary) }
        let delta = score - par
        if delta == 0 {
            return ("E", .textTertiary)
        }
        let raw = String(format: "%+.0f", Double(delta))
        return (raw.replacingOccurrences(of: "-", with: "\u{2212}"), delta < 0 ? .accent : .chartNegative)
    }

    private var roundSummaryHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Button {
                    courseNameDraft = displayedCourseName
                    courseNameSaveError = nil
                    showCourseNameEditor = true
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(displayedCourseName)
                            .font(GLFonts.sans(size: 14, weight: .semibold))
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.leading)
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit course name, \(displayedCourseName)")
                Text(roundMetaLine)
                    .font(.glFootnote)
                    .foregroundColor(.textTertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(headlineVsPar.text)
                    .font(GLFonts.mono(size: 28, weight: .semibold))
                    .foregroundColor(headlineVsPar.color)
                if let score = headerTotalScore {
                    Text("\(score) total")
                        .font(GLFonts.mono(size: 12, weight: .medium))
                        .foregroundColor(.textTertiary)
                }
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

    private var scorecardTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                headerCell("HOLE", width: tableLayout.hole, left: true)
                headerCell("PAR", width: tableLayout.par)
                headerCell("SCORE", width: tableLayout.score)
                headerCell("PUTTS", width: tableLayout.putts)
                headerCell("GIR", width: tableLayout.gir)
                headerCell("FIR", width: tableLayout.fir)
                headerCell("PEN", width: tableLayout.pen)
                headerCell("", width: tableLayout.chevron)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.bgElevated)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.borderDefault)
                    .frame(height: 1)
            }

            ForEach(holes.sorted { $0.holeNumber < $1.holeNumber }) { hole in
                NavigationLink {
                    HoleEditView(hole: hole, roundId: round.id)
                } label: {
                    HoleDetailRow(hole: hole, layout: tableLayout)
                }
                .buttonStyle(.plain)
                .navigationLinkIndicatorVisibility(.hidden)
                Rectangle()
                    .fill(Color.borderDefault)
                    .frame(height: 1)
            }

            HStack(spacing: 0) {
                totalsLabelCell("Total", width: tableLayout.hole + tableLayout.par)
                totalsNumericCell("\(tableTotals.score)", width: tableLayout.score)
                totalsNumericCell("\(tableTotals.putts)", width: tableLayout.putts)
                totalsNumericCell("\(tableTotals.gir)", width: tableLayout.gir)
                totalsNumericCell("\(tableTotals.fir)", width: tableLayout.fir)
                totalsNumericCell("\(tableTotals.penalties)", width: tableLayout.pen)
                totalsNumericCell("", width: tableLayout.chevron)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color.bgElevated)
        }
        .frame(maxWidth: .infinity)
        .glCardChromeFrame(outlined: true)
    }

    private func headerCell(_ text: String, width: CGFloat, left: Bool = false) -> some View {
        Text(text)
            .font(.glFilterActive)
            .foregroundColor(.textTertiary)
            .tracking(0.10 * 11)
            .frame(width: width, alignment: left ? .leading : .center)
    }

    private func totalsLabelCell(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.glFilterActive)
            .foregroundColor(.textTertiary)
            .tracking(0.06 * 11)
            .textCase(.uppercase)
            .frame(width: width, alignment: .leading)
    }

    private func totalsNumericCell(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(GLFonts.mono(size: 14, weight: .semibold))
            .foregroundColor(.textPrimary)
            .frame(width: width)
    }

    private var detailLoadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.accent)
            Text("Loading round details...")
                .font(.glSubhead)
                .foregroundColor(.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .top)
        .padding(.top, 12)
    }

    private func loadHoles() async {
        await MainActor.run { isLoading = true }
        let fetched = (try? await SupabaseService.shared.fetchHoles(roundId: round.id)) ?? []
        await MainActor.run {
            holes = fetched
            isLoading = false
        }
    }

    private func saveCourseNameEdit() async {
        let trimmed = courseNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await MainActor.run {
            isSavingCourseName = true
            courseNameSaveError = nil
        }
        do {
            try await SupabaseService.shared.updateRoundCourseName(roundId: round.id, courseName: trimmed)
            await MainActor.run {
                displayedCourseName = trimmed
                isSavingCourseName = false
                showCourseNameEditor = false
            }
            await roundStore.loadRounds()
        } catch {
            await MainActor.run {
                isSavingCourseName = false
                courseNameSaveError = "Couldn't save. Check your connection and try again."
            }
        }
    }

    private static func ymdDate(_ ymd: String) -> Date? {
        let head = String(ymd.prefix(10))
        let parts = head.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3,
              let y = Int(parts[0]),
              let m = Int(parts[1]),
              let d = Int(parts[2])
        else { return nil }
        var dc = DateComponents()
        dc.year = y
        dc.month = m
        dc.day = d
        return Calendar.current.date(from: dc)
    }
}

private struct HoleDetailRow: View {
    let hole: Hole
    let layout: RoundDetailTableLayout

    var body: some View {
        HStack(spacing: 0) {
            Text("\(hole.holeNumber)")
                .font(GLFonts.mono(size: 12, weight: .medium))
                .foregroundColor(.textTertiary)
                .frame(width: layout.hole, alignment: .leading)

            Text("\(hole.par)")
                .font(GLFonts.mono(size: 12, weight: .medium))
                .foregroundColor(.textTertiary)
                .frame(width: layout.par)

            compactScoreBadge
                .frame(width: layout.score)

            Text("\(hole.putts)")
                .font(GLFonts.mono(size: 13, weight: .medium))
                .foregroundColor(.textPrimary)
                .frame(width: layout.putts)

            boolCell(hole.gir, width: layout.gir)
            boolCell(hole.fir ?? false, width: layout.fir, showDash: hole.fir == nil)
            boolCell(hole.penalty ?? false, width: layout.pen)
            Text("›")
                .font(GLFonts.sans(size: 14, weight: .regular))
                .foregroundColor(.textTertiary)
                .frame(width: layout.chevron)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var compactScoreBadge: some View {
        let delta = hole.score - hole.par
        if delta <= -2 {
            Circle()
                .stroke(Color.textPrimary, lineWidth: 1.5)
                .frame(width: 22, height: 22)
                .overlay {
                    Circle()
                        .stroke(Color.textPrimary, lineWidth: 1.5)
                        .frame(width: 17, height: 17)
                }
                .overlay(scoreText)
        } else if delta == -1 {
            Circle()
                .stroke(Color.textPrimary, lineWidth: 1.5)
                .frame(width: 22, height: 22)
                .overlay(scoreText)
        } else if delta >= 2 {
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.textPrimary, lineWidth: 1.5)
                .frame(width: 22, height: 22)
                .overlay {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.textPrimary, lineWidth: 1.5)
                        .frame(width: 17, height: 17)
                }
                .overlay(scoreText)
        } else if delta == 1 {
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.textPrimary, lineWidth: 1.5)
                .frame(width: 22, height: 22)
                .overlay(scoreText)
        } else {
            scoreText
        }
    }

    private var scoreText: some View {
        Text("\(hole.score)")
            .font(GLFonts.mono(size: 12, weight: .semibold))
            .foregroundColor(.textPrimary)
    }

    private func boolCell(_ value: Bool, width: CGFloat, showDash: Bool = false) -> some View {
        Group {
            if showDash {
                Text("—")
                    .font(GLFonts.mono(size: 12, weight: .medium))
                    .foregroundColor(.textTertiary)
            } else if value {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.textPrimary)
            } else {
                Text("—")
                    .font(GLFonts.mono(size: 12, weight: .medium))
                    .foregroundColor(.textTertiary)
            }
        }
        .frame(width: width)
    }
}

private struct RoundDetailTableLayout {
    let hole: CGFloat
    let par: CGFloat
    let score: CGFloat
    let putts: CGFloat
    let gir: CGFloat
    let fir: CGFloat
    let pen: CGFloat
    let chevron: CGFloat

    private static let base = RoundDetailTableLayout(
        hole: 28,
        par: 28,
        score: 44,
        putts: 40,
        gir: 28,
        fir: 28,
        pen: 28,
        chevron: 20
    )

    private static let baseTotal: CGFloat = 244

    static func fitted(for availableWidth: CGFloat) -> RoundDetailTableLayout {
        let scale = max(1.0, availableWidth / baseTotal)
        return RoundDetailTableLayout(
            hole: base.hole * scale,
            par: base.par * scale,
            score: base.score * scale,
            putts: base.putts * scale,
            gir: base.gir * scale,
            fir: base.fir * scale,
            pen: base.pen * scale,
            chevron: base.chevron * scale
        )
    }
}
