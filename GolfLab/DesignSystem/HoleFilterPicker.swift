import SwiftUI

struct HoleFilterPicker: View {
    @Binding var selectedFilter: HoleFilter
    let availableRounds: [Round]
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(HoleFilter.allCases, id: \.self) { filter in
                let hasRounds = HoleFilterState.hasRounds(for: filter, in: availableRounds)
                let isSelected = selectedFilter == filter
                
                Button {
                    if hasRounds {
                        selectedFilter = filter
                        HoleFilterState.persistHoleFilter(filter)
                    }
                } label: {
                    Text(filter.displayTitle.uppercased())
                        .font(isSelected ? .glFilterActive : .glFilterInactive)
                        .tracking(0.08 * 11)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color.accentDim : Color.clear)
                        .foregroundColor(hasRounds ? (isSelected ? Color.accent : Color.textTertiary) : Color.textTertiary.opacity(0.4))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? Color.borderAccent : Color.borderDefault, lineWidth: 1)
                        )
                }
                .disabled(!hasRounds)
            }
        }
    }
}
