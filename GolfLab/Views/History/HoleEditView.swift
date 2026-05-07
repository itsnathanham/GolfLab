import SwiftUI
import UIKit

struct HoleEditView: View {
    let hole: Hole
    let roundId: UUID
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var roundStore: RoundStore

    @State private var activeHole: ActiveHole
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(hole: Hole, roundId: UUID) {
        self.hole = hole
        self.roundId = roundId
        self._activeHole = State(initialValue: ActiveHole(
            holeNumber: hole.holeNumber,
            par: hole.par,
            yardage: hole.yardage,
            strokeIndex: hole.strokeIndex
        ).applying(score: hole.score, putts: hole.putts, gir: hole.gir, fir: hole.fir, penalty: hole.penalty ?? false))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HoleMetaHeaderCard(
                    holeNumber: hole.holeNumber,
                    par: hole.par,
                    yardage: hole.yardage
                )
                .padding(.top, 8)

                HoleEntryForm(hole: activeHole, commitInPlace: false) { updated in
                    activeHole = updated
                    saveHole()
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.glSubhead)
                        .foregroundColor(.chartNegativeStrong)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, GLLayout.horizontalInset)
            .padding(.bottom, 32)
        }
        .background(Color.appBackground)
        .navigationTitle("Edit Hole \(hole.holeNumber)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func saveHole() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                let update = HoleUpdate(
                    score: activeHole.score,
                    putts: activeHole.putts,
                    gir: activeHole.gir,
                    fir: activeHole.fir,
                    penalty: activeHole.penalty
                )
                try await SupabaseService.shared.updateHole(holeId: hole.id, update: update)

                // Recalculate round totals from all holes
                let allHoles = try await SupabaseService.shared.fetchHoles(roundId: roundId)
                let firHoles = allHoles.filter { $0.par > 3 }
                try await SupabaseService.shared.updateRoundTotals(
                    roundId: roundId,
                    totalScore: allHoles.reduce(0) { $0 + $1.score },
                    totalPutts: allHoles.reduce(0) { $0 + $1.putts },
                    totalGir: allHoles.filter { $0.gir }.count,
                    totalFir: firHoles.filter { $0.fir == true }.count
                )

                await roundStore.loadRounds()
                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
            await MainActor.run { isSaving = false }
        }
    }
}

extension ActiveHole {
    func applying(score: Int, putts: Int, gir: Bool, fir: Bool?, penalty: Bool) -> ActiveHole {
        var copy = self
        copy.score    = score
        copy.putts    = putts
        copy.gir      = gir
        copy.fir      = fir
        copy.penalty  = penalty
        copy.isSaved  = true
        return copy
    }
}
