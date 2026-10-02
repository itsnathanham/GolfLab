import SwiftUI
import UIKit

/// Profile bag setup: default clubs, add/delete, autosave, ordered by family.
struct StockClubYardagesSection: View {
    @Binding var rows: [StockClubYardage]
    var onChange: () -> Void

    @State private var draftClub: StockClub?
    @State private var draftYardage: Int = GLStockClubYardages.defaultYardsWhenSetting
    @State private var draftHasYardage = false

    private var usedClubs: Set<StockClub> {
        Set(rows.map(\.club))
    }

    private var availableForDraft: [StockClub] {
        StockClub.allCases.filter { !usedClubs.contains($0) }
    }

    var body: some View {
        GLFormCard {
            VStack(alignment: .leading, spacing: 16) {
                GLFormFieldLabel(text: "Stock yardages")
                Text("Carry distances in yards. Changes save automatically. Bag sorts as driver, woods, irons, then wedges.")
                    .font(.glFootnote)
                    .foregroundColor(.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                if rows.isEmpty {
                    Text("No clubs yet. Add one below.")
                        .font(.glSubhead)
                        .foregroundColor(.textTertiary)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            clubRow(row: row, index: index)
                            if index < rows.count - 1 {
                                Rectangle()
                                    .fill(Color.borderDefault)
                                    .frame(height: 1)
                            }
                        }
                    }
                }

                addClubSlot
            }
        }
        .animation(.easeInOut(duration: 0.22), value: rows.map(\.id))
    }

    @ViewBuilder
    private func clubRow(row: StockClubYardage, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                clubMenu(
                    title: row.club.displayName,
                    selected: row.club,
                    excluding: usedClubs.subtracting([row.club])
                ) { club in
                    updateClub(at: index, club: club)
                }

                Spacer(minLength: 0)

                Button {
                    deleteRow(at: index)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.chartNegative)
                        .frame(width: 32, height: 32)
                        .background(Color.chartNegativeFill)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.borderPenalty, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete \(row.club.displayName)")
            }

            yardageStepper(yardage: row.yardage) { next in
                updateYardage(at: index, yardage: next)
            }
        }
    }

    private var addClubSlot: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add club")
                .font(GLFonts.sans(size: 12, weight: .medium))
                .foregroundColor(.textSecondary)

            if availableForDraft.isEmpty {
                Text("Every available club is already in your bag.")
                    .font(.glFootnote)
                    .foregroundColor(.textTertiary)
            } else {
                clubMenu(
                    title: draftClub?.displayName ?? "Select club",
                    selected: draftClub,
                    excluding: usedClubs,
                    placeholder: draftClub == nil
                ) { club in
                    draftClub = club
                    tryCommitDraft()
                }

                yardageStepper(yardage: draftHasYardage ? draftYardage : nil) { next in
                    draftYardage = next
                    draftHasYardage = true
                    tryCommitDraft()
                }
            }
        }
        .padding(.top, rows.isEmpty ? 0 : 4)
    }

    private func clubMenu(
        title: String,
        selected: StockClub?,
        excluding: Set<StockClub>,
        placeholder: Bool = false,
        onSelect: @escaping (StockClub) -> Void
    ) -> some View {
        Menu {
            ForEach(StockClub.allCases) { club in
                let taken = excluding.contains(club)
                Button {
                    onSelect(club)
                } label: {
                    if selected == club {
                        Label(club.displayName, systemImage: "checkmark")
                    } else {
                        Text(club.displayName)
                    }
                }
                .disabled(taken && selected != club)
            }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(GLFonts.sans(size: 14, weight: .semibold))
                    .foregroundColor(placeholder ? .textTertiary : .textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bgElevated)
            .cornerRadius(GLCardMetrics.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                    .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
            )
        }
    }

    private func yardageStepper(yardage: Int?, onChange: @escaping (Int) -> Void) -> some View {
        Group {
            if let yardage {
                StepperField(
                    label: "yards",
                    value: Binding(
                        get: { yardage },
                        set: { onChange(clampYards($0)) }
                    ),
                    min: GLStockClubYardages.minYards,
                    max: GLStockClubYardages.maxYards,
                    step: GLStockClubYardages.step
                )
            } else {
                // Unset row: same chrome as StepperField; + starts at the default carry.
                HStack(alignment: .center, spacing: 0) {
                    stepSideButton(systemName: "minus", enabled: false, action: {})
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Text("—")
                            .font(GLFonts.mono(size: 34, weight: .semibold))
                            .foregroundColor(.textTertiary)
                        Text("YARDS")
                            .font(.glEyebrow)
                            .foregroundColor(.textTertiary)
                            .tracking(0.06 * 11)
                            .textCase(.uppercase)
                            .padding(.top, 1)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    stepSideButton(systemName: "plus", enabled: true) {
                        onChange(GLStockClubYardages.defaultYardsWhenSetting)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 62)
                .background(Color.cardBackground)
                .cornerRadius(GLCardMetrics.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                        .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Yards, not set")
                .accessibilityHint("Increases to set yardage")
            }
        }
    }

    private func stepSideButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(enabled ? .textPrimary : .textTertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .frame(width: 62, height: 62)
        .background(Color.bgElevated)
    }

    private func clampYards(_ value: Int) -> Int {
        min(GLStockClubYardages.maxYards, max(GLStockClubYardages.minYards, value))
    }

    private func updateClub(at index: Int, club: StockClub) {
        guard rows.indices.contains(index) else { return }
        guard !usedClubs.contains(club) || rows[index].club == club else { return }
        rows[index].club = club
        rows = GLStockClubYardages.sorted(rows)
        onChange()
    }

    private func updateYardage(at index: Int, yardage: Int) {
        guard rows.indices.contains(index) else { return }
        rows[index].yardage = clampYards(yardage)
        onChange()
    }

    private func deleteRow(at index: Int) {
        guard rows.indices.contains(index) else { return }
        rows.remove(at: index)
        onChange()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func tryCommitDraft() {
        guard let club = draftClub, draftHasYardage else { return }
        guard !usedClubs.contains(club) else { return }
        let entry = StockClubYardage(club: club, yardage: clampYards(draftYardage))
        rows = GLStockClubYardages.sorted(rows + [entry])
        draftClub = nil
        draftYardage = GLStockClubYardages.defaultYardsWhenSetting
        draftHasYardage = false
        onChange()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
