import SwiftUI
import UIKit

struct HoleEntryView: View {
    @EnvironmentObject private var roundStore: RoundStore
    @State private var showEndRound = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let round = roundStore.activeRound, round.currentHoleIndex < round.holes.count {
                    let hole = round.holes[round.currentHoleIndex]
                    // UI progress/totals should update live while editing the current hole.
                    let progressCount = min(round.currentHoleIndex + 1, round.holes.count)
                    let throughCurrent = Array(round.holes.prefix(progressCount))
                    let progress = round.holes.isEmpty ? 0 : CGFloat(progressCount) / CGFloat(round.holes.count)
                    let liveScore = throughCurrent.reduce(0) { $0 + $1.score }
                    let livePar = throughCurrent.reduce(0) { $0 + $1.par }
                    let vs = liveScore - livePar

                    topNav
                        .padding(.horizontal, GLLayout.horizontalInset)
                        .padding(.top, GLTopBarMetrics.screenRootTopPadding)
                        .padding(.bottom, GLTopBarMetrics.titleBarBottomSpacing)

                    holeHeader(hole: hole)
                        .padding(.horizontal, GLLayout.horizontalInset)
                        .padding(.bottom, 12)

                    progressRow(progress: progress, progressCount: progressCount, total: round.holes.count)
                        .padding(.horizontal, GLLayout.horizontalInset)
                    scoreVsParRow(vs: vs, hasSavedHoles: progressCount > 0)
                        .padding(.horizontal, GLLayout.horizontalInset)
                        .padding(.top, 6)
                        .padding(.bottom, 18)

                    HoleEntryForm(hole: hole, commitInPlace: true) { updated in
                        roundStore.saveHole(updated)
                        advance()
                    }
                    .id(hole.holeNumber)
                    .padding(.horizontal, GLLayout.horizontalInset)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showEndRound) {
            EndRoundView()
        }
    }
    
    private var topNav: some View {
        GLScreenTopBar(title: "Scorecard") {
            Button("← Round") {
                roundStore.persistUnsavedCurrentHoleIfEligible()
                showEndRound = true
            }
            .font(GLFonts.sans(size: 14, weight: .regular))
            .foregroundColor(.accent)
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
        } trailing: {
            Color.clear
        }
    }
    
    private func holeHeader(hole: ActiveHole) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text("\(hole.holeNumber)")
                    .font(GLFonts.mono(size: 28, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
                Text("Par \(hole.par)")
                    .font(GLFonts.sans(size: 12, weight: .semibold))
                    .foregroundColor(.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentDim)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.borderAccent, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(.bottom, 8)
            
            if let y = hole.yardage {
                Text("\(y) yds")
                    .font(.glFootnote)
                    .foregroundColor(.textTertiary)
            }
            
            Rectangle()
                .fill(Color.borderDefault)
                .frame(height: 1)
                .padding(.top, 8)
                .padding(.bottom, 8)
            Text(parAverageLine(for: hole.par))
                .font(.glFootnote)
                .foregroundColor(.accent)
                .opacity(0.85)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.cardBackground)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.accent.opacity(0.6))
                .frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
        )
    }

    private func parAverageLine(for par: Int) -> String {
        if let avg = roundStore.averageScoreForPar(par) {
            return String(format: "Your par %d avg: %.1f", par, avg)
        }
        return "Your par \(par) avg: --"
    }
    
    private func progressRow(progress: CGFloat, progressCount: Int, total: Int) -> some View {
        HStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.borderDefault)
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accent.opacity(0.45))
                        .frame(width: geo.size.width * progress, height: 3)
                }
            }
            .frame(height: 3)
            Text("\(progressCount) of \(total) holes")
                .font(.glFootnote)
                .foregroundColor(.textTertiary)
        }
    }
    
    private func scoreVsParRow(vs: Int, hasSavedHoles: Bool) -> some View {
        HStack {
            Spacer()
            Text("Current round: ")
                .font(.glFootnote)
                .foregroundColor(.textTertiary)
            Text(hasSavedHoles ? formatVs(vs) : "--")
                .font(GLFonts.mono(size: 13, weight: .semibold))
                .foregroundColor(vs <= 0 ? .accent : .chartNegative)
        }
    }
    
    private func formatVs(_ v: Int) -> String {
        if v == 0 { return "E" }
        return v > 0 ? "+\(v)" : "\(v)"
    }

    private func advance() {
        guard let round = roundStore.activeRound else { return }
        if round.currentHoleIndex < round.holes.count - 1 {
            roundStore.updateActiveRoundCurrentHoleIndex(round.currentHoleIndex + 1)
        } else {
            showEndRound = true
        }
    }

}

// MARK: - Scorecard row with traditional golf notation

struct ScorecardRow: View {
    let hole: ActiveHole

    var body: some View {
        HStack {
            Text("\(hole.holeNumber)")
                .font(GLFonts.mono(size: 14, weight: .medium))
                .foregroundColor(.textSecondary)
                .frame(width: 28, alignment: .leading)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Par")
                    .font(.glCaption)
                    .foregroundColor(.textTertiary)
                    .tracking(0.10 * 12)
                    .textCase(.uppercase)
                Text("\(hole.par)")
                    .font(GLFonts.mono(size: 12, weight: .medium))
                    .foregroundColor(.textTertiary)
            }

            Spacer()

            ScorecardBadge(score: hole.score, par: hole.par)

            Image(systemName: "pencil")
                .font(.glCaption)
                .foregroundColor(.textTertiary)
                .padding(.leading, 8)
        }
        .padding(.horizontal, GLLayout.horizontalInset)
        .padding(.vertical, 10)
    }
}

// MARK: - Traditional golf scorecard badge

struct ScorecardBadge: View {
    /// Ink and optional color cues for in-round entry vs. neutral history scorecards.
    enum Appearance: Equatable {
        /// Semantic score palette (docs/design.md).
        case colorCoded
        /// Single ink for strokes and score (paper scorecard style).
        case traditionalInk
    }

    let score: Int
    let par: Int
    var appearance: Appearance = .colorCoded

    private var vsP: Int { score - par }

    private static let ink = Color.textPrimary
    private let strokeW: CGFloat = 1

    var body: some View {
        ZStack {
            outerDecoration
            innerDecoration
            Text("\(score)")
                .font(GLFonts.mono(size: 12, weight: .semibold))
                .foregroundColor(scoreTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(minWidth: 24, idealWidth: 28, maxHeight: 24)
        }
        .frame(width: 44, height: 44)
    }

    private func strokeColorOuterCoded() -> Color? {
        switch appearance {
        case .traditionalInk:
            switch vsP {
            case ..<(-1), 2...: return Self.ink
            default: return nil
            }
        case .colorCoded:
            switch vsP {
            case ..<(-1): return .scoreEagleText
            case 2...: return .scoreDoubleText
            default: return nil
            }
        }
    }

    private func strokeColorInnerCoded() -> Color? {
        switch appearance {
        case .traditionalInk:
            if vsP < 0 || vsP >= 1 { return Self.ink }
            return nil
        case .colorCoded:
            switch vsP {
            case ..<(-1): return .scoreEagleText
            case -1: return .scoreBirdieText
            case 1: return .scoreBogeyText
            case 2...: return .scoreDoubleText
            default: return nil
            }
        }
    }

    @ViewBuilder
    private var outerDecoration: some View {
        if let stroke = strokeColorOuterCoded() {
            if vsP < -1 {
                Circle()
                    .stroke(stroke, lineWidth: strokeW)
                    .frame(width: 38, height: 38)
            } else if vsP >= 2 {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(stroke, lineWidth: strokeW)
                    .frame(width: 38, height: 38)
            }
        }
    }

    @ViewBuilder
    private var innerDecoration: some View {
        if let stroke = strokeColorInnerCoded() {
            if vsP < 0 {
                Circle()
                    .stroke(stroke, lineWidth: strokeW)
                    .frame(width: 28, height: 28)
            } else if vsP >= 1 {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(stroke, lineWidth: strokeW)
                    .frame(width: 28, height: 28)
            }
        }
    }

    private var scoreTextColor: Color {
        switch appearance {
        case .traditionalInk:
            return Self.ink
        case .colorCoded:
            switch vsP {
            case ..<(-1): return .scoreEagleText
            case -1: return .scoreBirdieText
            case 0: return .scoreParText
            case 1: return .scoreBogeyText
            default: return .scoreDoubleText
            }
        }
    }
}

// MARK: - In-round hole edit sheet

struct ScorecardHoleEditSheet: View {
    let hole: ActiveHole
    let onSave: (ActiveHole) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var edited: ActiveHole

    init(hole: ActiveHole, onSave: @escaping (ActiveHole) -> Void) {
        self.hole = hole
        self.onSave = onSave
        self._edited = State(initialValue: hole)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HoleMetaHeaderCard(
                    holeNumber: hole.holeNumber,
                    par: hole.par,
                    yardage: hole.yardage
                )
                .padding(.horizontal, GLLayout.horizontalInset)
                .padding(.top, 8)

                HoleEntryForm(hole: edited, commitInPlace: true) { updated in
                    onSave(updated)
                    dismiss()
                }
                .padding(.horizontal, GLLayout.horizontalInset)

                Spacer()
            }
            .background(Color.appBackground)
            .navigationTitle("Edit Hole \(hole.holeNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - ActiveHole Identifiable for sheet(item:)

extension ActiveHole: Identifiable {
    var id: Int { holeNumber }
}

// MARK: - Stepper field (shared)

struct StepperField: View {
    /// Side buttons are large enough for glove / thumb use (brief ~56pt tap targets — use slightly taller row).
    private static let tapSide: CGFloat = 62

    let label: String
    @Binding var value: Int
    let min: Int
    let max: Int

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            stepButton(
                systemName: "minus",
                enabled: value > min,
                action: {
                    value -= 1
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            )
            .frame(width: Self.tapSide, height: Self.tapSide)
            .background(Color.bgElevated)

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Text("\(value)")
                    .font(GLFonts.mono(size: 34, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(label.uppercased())
                    .font(.glEyebrow)
                    .foregroundColor(.textTertiary)
                    .tracking(0.06 * 11)
                    .textCase(.uppercase)
                    .padding(.top, 1)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.tapSide)

            stepButton(
                systemName: "plus",
                enabled: value < max,
                action: {
                    value += 1
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            )
            .frame(width: Self.tapSide, height: Self.tapSide)
            .background(Color.bgElevated)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: Self.tapSide)
        .background(Color.cardBackground)
        .cornerRadius(GLCardMetrics.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
        )
    }

    private func stepButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(enabled ? .textPrimary : .textTertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(systemName == "minus" ? "Decrease \(label)" : "Increase \(label)")
    }
}

// MARK: - Hole entry form (shared with edit)

struct HoleEntryForm: View {
    @EnvironmentObject private var roundStore: RoundStore

    /// Frozen at init so we always merge into the correct hole row (par, number, tee metadata).
    private let holeNumber: Int
    private let par: Int
    private let yardage: Int?
    private let strokeIndex: Int?
    /// When true (in-progress round on iPhone), Save writes score/putts/GIR/FIR/`isSaved` in place (no `builtHole()`).
    private let commitInPlace: Bool
    let onSave: (ActiveHole) -> Void

    @State private var score: Int
    @State private var putts: Int
    @State private var gir: Bool
    @State private var firOn: Bool
    @State private var penalty = false

    init(hole: ActiveHole, commitInPlace: Bool = false, onSave: @escaping (ActiveHole) -> Void) {
        self.holeNumber = hole.holeNumber
        self.par = hole.par
        self.yardage = hole.yardage
        self.strokeIndex = hole.strokeIndex
        self.commitInPlace = commitInPlace
        self.onSave = onSave
        _score = State(initialValue: hole.score)
        _putts = State(initialValue: hole.putts)
        _gir = State(initialValue: hole.gir)
        _firOn = State(initialValue: hole.fir ?? false)
        _penalty = State(initialValue: hole.penalty)
    }

    private var liveActiveHole: ActiveHole? {
        roundStore.activeRound?.holes.first { $0.holeNumber == holeNumber }
    }

    private var girBinding: Binding<Bool> {
        Binding(
            get: {
                if let live = liveActiveHole { return live.gir }
                return gir
            },
            set: { newValue in
                gir = newValue
                if liveActiveHole != nil {
                    roundStore.patchActiveHole(holeNumber: holeNumber) { $0.gir = newValue }
                }
            }
        )
    }

    private var firBinding: Binding<Bool> {
        Binding(
            get: {
                if let live = liveActiveHole { return live.fir ?? false }
                return firOn
            },
            set: { newValue in
                firOn = newValue
                if liveActiveHole != nil {
                    roundStore.patchActiveHole(holeNumber: holeNumber) { $0.fir = par > 3 ? newValue : nil }
                }
            }
        )
    }

    private var penaltyBinding: Binding<Bool> {
        Binding(
            get: {
                if let live = liveActiveHole { return live.penalty }
                return penalty
            },
            set: { newValue in
                penalty = newValue
                if liveActiveHole != nil {
                    roundStore.patchActiveHole(holeNumber: holeNumber) { $0.penalty = newValue }
                }
            }
        )
    }

    /// If `patchActiveHole` did not run (e.g. `liveActiveHole` was nil in the setter), @State still holds the toggle; OR with store so we never save a false when the user turned it on.
    private var persistedGir: Bool {
        gir || (liveActiveHole?.gir ?? false)
    }

    private var persistedFairwayHit: Bool {
        guard par > 3 else { return false }
        return firOn || (liveActiveHole?.fir ?? false)
    }

    private var persistedPenalty: Bool {
        penalty || (liveActiveHole?.penalty ?? false)
    }

    private func builtHole() -> ActiveHole {
        var h = ActiveHole(holeNumber: holeNumber, par: par, yardage: yardage, strokeIndex: strokeIndex)
        h.score = score
        h.putts = putts
        if let live = liveActiveHole {
            h.gir = live.gir
            h.fir = live.fir
            h.penalty = live.penalty
        } else {
            h.gir = gir
            h.fir = par > 3 ? firOn : nil
            h.penalty = penalty
        }
        return h
    }

    var body: some View {
        VStack(spacing: 0) {
            GLSectionFieldHeading(text: "Score")
            StepperField(label: "strokes", value: $score, min: 1, max: 12)
                .padding(.bottom, 16)

            GLSectionFieldHeading(text: "Putts")
            StepperField(label: "putts", value: $putts, min: 0, max: 5)
                .padding(.bottom, 22)

            GLSectionFieldHeading(text: "Stats")
            HStack(spacing: 6) {
                StatToggle(label: "GIR", subtitle: "Green in reg", isOn: girBinding, style: .positive)
                StatToggle(label: "FIR", subtitle: par > 3 ? "Fairway in reg" : "N/A par 3", isOn: firBinding, style: .positive, isEnabled: par > 3)
                StatToggle(label: "Penalty", subtitle: "OB / water", isOn: penaltyBinding, style: .penalty)
            }
            .padding(.bottom, 22)

            GLPrimaryCTAButton(title: "Save hole →") {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                if commitInPlace {
                    roundStore.commitInProgressHoleSave(
                        holeNumber: holeNumber,
                        par: par,
                        score: score,
                        putts: putts,
                        gir: persistedGir,
                        fir: par > 3 ? persistedFairwayHit : nil,
                        penalty: persistedPenalty
                    )
                    if let committed = roundStore.activeRound?.holes.first(where: { $0.holeNumber == holeNumber }) {
                        onSave(committed)
                    }
                } else {
                    onSave(builtHole())
                }
            }
        }
        .onChange(of: score) { _, newValue in
            if commitInPlace {
                roundStore.patchActiveHole(holeNumber: holeNumber) { $0.score = newValue }
            }
        }
        .onChange(of: putts) { _, newValue in
            if commitInPlace {
                roundStore.patchActiveHole(holeNumber: holeNumber) { $0.putts = newValue }
            }
        }
    }
    
}
