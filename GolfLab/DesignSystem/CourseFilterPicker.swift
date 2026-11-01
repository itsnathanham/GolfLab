import SwiftUI

/// Stats course filter; "All courses" is a real selection, so the pill is always in the accent state.
struct CourseFilterPicker: View {
    @Binding var selectedCourseKey: String?
    let courses: [CourseCache.CachedCourse]

    private static let allCoursesTitle = "All courses"

    var body: some View {
        GLFilterMenuPill(title: pillTitle, maxTitleWidth: 170) {
            Button {
                selectedCourseKey = nil
            } label: {
                GLFilterMenuRow(title: Self.allCoursesTitle, isSelected: selectedCourseKey == nil)
            }

            ForEach(courses) { course in
                Button {
                    selectedCourseKey = course.normalizedKey
                } label: {
                    GLFilterMenuRow(
                        title: "\(course.displayName) (\(course.playCount))",
                        isSelected: selectedCourseKey == course.normalizedKey
                    )
                }
            }
        }
    }

    private var pillTitle: String {
        guard let selectedCourseKey,
              let course = courses.first(where: { $0.normalizedKey == selectedCourseKey })
        else { return Self.allCoursesTitle }
        return course.displayName
    }
}
