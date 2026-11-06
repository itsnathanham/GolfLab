import SwiftUI

struct CourseAutocompleteDropdown: View {
    let matches: [CourseCache.CachedCourse]
    let onSelect: (CourseCache.CachedCourse) -> Void

    var body: some View {
        if !matches.isEmpty {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.borderDefault)
                    .frame(height: 1)
                
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(matches.enumerated()), id: \.element.id) { index, course in
                            Button {
                                onSelect(course)
                            } label: {
                                HStack(alignment: .center, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(course.displayName)
                                            .font(.glBody)
                                            .foregroundColor(.textPrimary)
                                            .lineLimit(1)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        Text(Self.detailText(for: course))
                                            .font(.glFootnote)
                                            .foregroundColor(.textTertiary)
                                    }
                                    
                                    Image(systemName: "arrow.turn.down.left")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.textTertiary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                                .background(Color.bgCard)
                            }
                            .buttonStyle(.plain)

                            if index < matches.count - 1 {
                                Rectangle()
                                    .fill(Color.borderDefault)
                                    .frame(height: 1)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
            .background(Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadius)
                    .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
            )
        }
    }

    private static func detailText(for course: CourseCache.CachedCourse) -> String {
        "\(course.totalHoles) holes · \(course.playCount) round\(course.playCount == 1 ? "" : "s")"
    }
}
