import SwiftUI

struct HoleFilterPicker: View {
    @Binding var selectedFilter: HoleFilter
    let availableRounds: [Round]

    var body: some View {
        GLFilterMenuPill(title: selectedFilter.displayTitle, minWidth: 100) {
            ForEach(HoleFilter.allCases, id: \.self) { filter in
                let hasRounds = HoleFilterState.hasRounds(for: filter, in: availableRounds)
                Button {
                    selectedFilter = filter
                    HoleFilterState.persistHoleFilter(filter)
                } label: {
                    GLFilterMenuRow(title: filter.displayTitle, isSelected: selectedFilter == filter)
                }
                .disabled(!hasRounds)
            }
        }
    }
}
