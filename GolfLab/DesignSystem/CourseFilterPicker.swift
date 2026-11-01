import SwiftUI

/// Stats course filter in the same pill chrome as `HoleFilterPicker`; lit up only while a single course is selected.
struct CourseFilterPicker: View {
    @Binding var selectedCourseKey: String?
    let courses: [CourseCache.CachedCourse]

    private static let allCoursesTitle = "All courses"

    var body: some View {
        Menu {
            Button {
                selectedCourseKey = nil
            } label: {
                menuRow(title: Self.allCoursesTitle, isSelected: selectedCourseKey == nil)
            }

            ForEach(courses) { course in
                Button {
                    selectedCourseKey = course.normalizedKey
                } label: {
                    menuRow(
                        title: "\(course.displayName) (\(course.playCount))",
                        isSelected: selectedCourseKey == course.normalizedKey
                    )
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(pillTitle.uppercased())
                    .font(isCourseSelected ? .glFilterActive : .glFilterInactive)
                    .tracking(0.08 * 11)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 170)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isCourseSelected ? Color.accentDim : Color.clear)
            .foregroundColor(isCourseSelected ? Color.accent : Color.textTertiary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isCourseSelected ? Color.borderAccent : Color.borderDefault, lineWidth: 1)
            )
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private var selectedCourse: CourseCache.CachedCourse? {
        guard let selectedCourseKey else { return nil }
        return courses.first { $0.normalizedKey == selectedCourseKey }
    }

    private var isCourseSelected: Bool {
        selectedCourse != nil
    }

    private var pillTitle: String {
        selectedCourse?.displayName ?? Self.allCoursesTitle
    }

    @ViewBuilder
    private func menuRow(title: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }
}
