import SwiftUI

struct HoleFilterPicker: View {
    @Binding var selectedFilter: HoleFilter
    let availableRounds: [Round]
    
    var body: some View {
        Picker("", selection: $selectedFilter) {
            ForEach(HoleFilter.allCases, id: \.self) { filter in
                let hasRounds = HoleFilterState.hasRounds(for: filter, in: availableRounds)
                Text(filter.displayTitle)
                    .tag(filter)
                    .disabled(!hasRounds)
            }
        }
        .pickerStyle(.menu)
        .onChange(of: selectedFilter) { _, newValue in
            HoleFilterState.persistHoleFilter(newValue)
        }
        .buttonStyle(.plain)
        .overlay(
            HStack(spacing: 6) {
                Text(selectedFilter.displayTitle.uppercased())
                    .font(.glFilterActive)
                    .tracking(0.08 * 11)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .frame(minWidth: 100)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.accentDim)
            .foregroundColor(.accent)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.borderAccent, lineWidth: 1)
            )
            .allowsHitTesting(false)
        )
        .animation(.none, value: selectedFilter)
    }
}
