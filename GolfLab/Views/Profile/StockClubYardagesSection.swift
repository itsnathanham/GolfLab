import SwiftUI
import UIKit

/// Profile bag setup: default clubs, add/delete, autosave, bag-ordered.
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
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            clubRow(row: row, index: index)
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

                GLCircleTrashButton(accessibilityLabel: "Delete \(row.club.displayName)") {
                    deleteRow(at: index)
                }
            }

            yardsStepper(
                value: Binding(
                    get: { row.yardage ?? GLStockClubYardages.defaultYardsWhenSetting },
                    set: { updateYardage(at: index, yardage: $0) }
                )
            )
        }
    }

    private var addClubSlot: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldCaption("Add club")

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

                yardsStepper(value: draftYardageBinding)
            }
        }
        .padding(.top, rows.isEmpty ? 0 : 4)
    }

    private func fieldCaption(_ text: String) -> some View {
        Text(text)
            .font(.glCaption)
            .foregroundColor(.textSecondary)
    }

    private func yardsStepper(value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldCaption("Yards")
            StepperField(
                label: "yards",
                value: value,
                min: GLStockClubYardages.minYards,
                max: GLStockClubYardages.maxYards,
                step: GLStockClubYardages.step
            )
        }
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
            HStack(spacing: 8) {
                Text(title)
                    .font(.glBody)
                    .foregroundColor(placeholder ? .textTertiary : .textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bgElevated)
            .cornerRadius(GLCardMetrics.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                    .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
            )
        }
    }

    private var draftYardageBinding: Binding<Int> {
        Binding(
            get: { draftHasYardage ? draftYardage : GLStockClubYardages.defaultYardsWhenSetting },
            set: { next in
                draftYardage = GLStockClubYardages.clampYards(next)
                draftHasYardage = true
                tryCommitDraft()
            }
        )
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
        rows[index].yardage = GLStockClubYardages.clampYards(yardage)
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
        let entry = StockClubYardage(club: club, yardage: GLStockClubYardages.clampYards(draftYardage))
        rows = GLStockClubYardages.sorted(rows + [entry])
        draftClub = nil
        draftYardage = GLStockClubYardages.defaultYardsWhenSetting
        draftHasYardage = false
        onChange()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
