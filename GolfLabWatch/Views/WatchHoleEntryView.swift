import SwiftUI
import WatchKit

struct WatchHoleEntryView: View {
    @EnvironmentObject private var session: WatchSessionService
    @State private var score: Int = 4
    @State private var crownValue: Double = 4
    @State private var putts: Int = 2
    @State private var gir: Bool = false
    @State private var fir: Bool = false
    @State private var penalty: Bool = false
    @State private var showEndRound = false

    private var currentHole: WatchHoleSetup? { session.currentHole }
    private var par: Int { currentHole?.par ?? 4 }
    private var displayHoleOrdinal: Int { currentHole?.holeNumber ?? session.currentHoleIndex + 1 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                holeHeader

                Group {
                    WatchMetricStepper(
                        title: "Score",
                        value: $score,
                        min: 1,
                        max: 12,
                        valuePointSize: 30,
                        buttonSize: 44
                    )
                }
                .digitalCrownRotation($crownValue, from: 1.0, through: 12.0, by: 1.0, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                .onChange(of: crownValue) { _, newValue in
                    score = Int(newValue.rounded())
                }

                WatchMetricStepper(
                    title: "Putts",
                    value: $putts,
                    min: 0,
                    max: 5,
                    valuePointSize: 24,
                    buttonSize: 40
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Stats")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(WatchPalette.textTertiary)
                        .textCase(.uppercase)
                    WatchToggle(label: "GIR", isOn: $gir, kind: .stat)
                    if par > 3 {
                        WatchToggle(label: "FIR", isOn: $fir, kind: .stat)
                    }
                    WatchToggle(label: "Penalty", isOn: $penalty, kind: .penalty)
                }

                saveButton
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(WatchPalette.bg)
        .navigationTitle("Hole \(displayHoleOrdinal)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { resetToDefaults() }
        .onChange(of: session.syncGeneration) { _, _ in
            resetToDefaults()
        }
        .sheet(isPresented: $showEndRound) {
            WatchEndRoundView()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEndRound = true
                } label: {
                    Image(systemName: "flag.checkered")
                        .foregroundColor(WatchPalette.chartNegativeStrong)
                }
            }
        }
    }

    // MARK: - Subviews

    private var holeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("HOLE \(displayHoleOrdinal)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(WatchPalette.textTertiary)
                Text("Par \(par)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(WatchPalette.textPrimary)
                if let yardage = currentHole?.yardage {
                    Text("\(yardage)y")
                        .font(.system(size: 11))
                        .foregroundColor(WatchPalette.textSecondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                let vs = session.scoreVsPar
                Text(vs == 0 ? "E" : (vs > 0 ? "+\(vs)" : "\(vs)"))
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundColor(vs <= 0 ? WatchPalette.chartPositive : WatchPalette.chartNegative)
                Text("\(session.currentHoleIndex + 1)/\(session.totalHoles)")
                    .font(.system(size: 11))
                    .foregroundColor(WatchPalette.textSecondary)
            }
        }
    }

    private var saveButton: some View {
        Button {
            saveHole()
        } label: {
            Text("Save hole")
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(WatchPalette.accent)
    }

    // MARK: - Logic

    private func resetToDefaults() {
        score = par
        crownValue = Double(par)
        putts = 2
        gir = false
        fir = false
        penalty = false
    }

    private func saveHole() {
        guard let setupHole = currentHole else { return }
        WKInterfaceDevice.current().play(.success)

        let entry = WatchHoleEntry(
            holeNumber: setupHole.holeNumber,
            par: setupHole.par,
            score: score,
            putts: putts,
            gir: gir,
            fir: setupHole.par > 3 ? fir : nil,
            penalty: penalty
        )

        session.sendHoleEntry(entry)

        if session.currentHoleIndex < session.totalHoles - 1 {
            session.advanceHole()
            resetToDefaults()
        } else {
            showEndRound = true
        }
    }
}

// MARK: - Full-width numeric stepper (generous tap targets)

struct WatchMetricStepper: View {
    let title: String
    @Binding var value: Int
    let min: Int
    let max: Int
    var valuePointSize: CGFloat = 28
    var buttonSize: CGFloat = 42

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(WatchPalette.textTertiary)
                .textCase(.uppercase)
            HStack(alignment: .center, spacing: 10) {
                stepButton(delta: -1)
                Spacer(minLength: 6)
                Text("\(value)")
                    .font(.system(size: valuePointSize, weight: .semibold, design: .monospaced))
                    .foregroundColor(WatchPalette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Spacer(minLength: 6)
                stepButton(delta: 1)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func stepButton(delta: Int) -> some View {
        let canStep = delta < 0 ? value > min : value < max
        return Button {
            guard canStep else { return }
            value += delta
            WKInterfaceDevice.current().play(.click)
        } label: {
            Image(systemName: delta < 0 ? "minus" : "plus")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(WatchPalette.textPrimary)
                .frame(width: buttonSize, height: buttonSize)
                .contentShape(Circle())
                .background(canStep ? WatchPalette.elevated : WatchPalette.elevated.opacity(0.55))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canStep)
        .accessibilityLabel(delta < 0 ? "Decrease \(title)" : "Increase \(title)")
    }
}

// MARK: - Watch toggle

struct WatchToggle: View {
    enum Kind {
        case stat
        case penalty
    }

    let label: String
    @Binding var isOn: Bool
    var kind: Kind = .stat

    var body: some View {
        Button {
            isOn.toggle()
            WKInterfaceDevice.current().play(.click)
        } label: {
            HStack(spacing: 10) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 0)
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(iconColor)
            }
            .foregroundColor(labelColor)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 46)
            .background(backgroundColor)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isOn)
    }

    private var labelColor: Color {
        isOn ? onLabelColor : WatchPalette.textSecondary
    }

    private var iconColor: Color {
        if isOn {
            switch kind {
            case .stat: return WatchPalette.accent
            case .penalty: return WatchPalette.chartNegativeStrong
            }
        }
        return WatchPalette.textSecondary
    }

    private var backgroundColor: Color {
        switch kind {
        case .stat:
            if isOn { return WatchPalette.accent.opacity(0.14) }
            return WatchPalette.elevated
        case .penalty:
            if isOn { return WatchPalette.chartNegativeStrong.opacity(0.16) }
            return WatchPalette.elevated
        }
    }

    private var onLabelColor: Color {
        switch kind {
        case .stat:
            return WatchPalette.accent
        case .penalty:
            return WatchPalette.chartNegativeStrong
        }
    }
}
