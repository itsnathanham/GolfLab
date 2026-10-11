import SwiftUI

struct HoleFilterPicker: View {
    @Binding var selectedFilter: HoleFilter
    let availableRounds: [Round]
    
    var body: some View {
        Menu {
            ForEach(HoleFilter.allCases, id: \.self) { filter in
                let hasRounds = HoleFilterState.hasRounds(for: filter, in: availableRounds)
                Button {
                    if hasRounds {
                        selectedFilter = filter
                        HoleFilterState.persistHoleFilter(filter)
                    }
                } label: {
                    HStack {
                        Text(filter.displayTitle)
                        if selectedFilter == filter {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .disabled(!hasRounds)
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedFilter.displayTitle.uppercased())
                    .font(.glFilterActive)
                    .tracking(0.08 * 11)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.accentDim)
            .foregroundColor(.accent)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.borderAccent, lineWidth: 1)
            )
        }
    }
}
