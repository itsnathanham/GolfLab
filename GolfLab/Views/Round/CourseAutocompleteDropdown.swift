import SwiftUI

struct CourseAutocompleteDropdown: View {
    let matches: [CourseCache.CachedCourse]
    let onSelect: (CourseCache.CachedCourse) -> Void
    
    var body: some View {
        if !matches.isEmpty {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(matches.enumerated()), id: \.element.id) { index, course in
                            Button {
                                onSelect(course)
                            } label: {
                                HStack {
                                    Text(course.displayName)
                                        .font(.glBody)
                                        .foregroundColor(.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            if index < matches.count - 1 {
                                Rectangle()
                                    .fill(Color.borderDefault)
                                    .frame(height: 1)
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                    .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 2)
        }
    }
}
