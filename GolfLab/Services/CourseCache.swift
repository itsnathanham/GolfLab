import Foundation

/// Manages a normalized cache of courses extracted from round history.
/// Handles case-insensitive matching and provides course suggestions for autocomplete.
@MainActor
final class CourseCache: ObservableObject {
    
    @Published private(set) var courses: [CachedCourse] = []
    
    private var normalizedLookup: [String: CachedCourse] = [:]
    
    struct CachedCourse: Identifiable, Equatable {
        let id: String
        var displayName: String
        var totalHoles: Int
        var holePars: [Int]
        var lastPlayedDate: String
        var playCount: Int
        
        var normalizedKey: String {
            id
        }
    }
    
    func rebuild(from rounds: [Round], holesByRoundId: [UUID: [Hole]]) {
        var courseData: [String: CourseData] = [:]
        
        for round in rounds.sortedByDatePlayedDescending() {
            let key = Self.normalizeCourseName(round.courseName)
            guard !key.isEmpty else { continue }
            
            let holes = holesByRoundId[round.id] ?? []
            let pars = holes.sorted { $0.holeNumber < $1.holeNumber }.map(\.par)
            
            if var existing = courseData[key] {
                existing.playCount += 1
                if round.datePlayed > existing.lastPlayedDate {
                    existing.displayName = round.courseName
                    existing.lastPlayedDate = round.datePlayed
                    if !pars.isEmpty {
                        existing.holePars = pars
                        existing.totalHoles = round.holes
                    }
                }
                courseData[key] = existing
            } else {
                courseData[key] = CourseData(
                    normalizedKey: key,
                    displayName: round.courseName,
                    totalHoles: round.holes,
                    holePars: pars.isEmpty ? Array(repeating: 4, count: round.holes) : pars,
                    lastPlayedDate: round.datePlayed,
                    playCount: 1
                )
            }
        }
        
        let cached = courseData.values.map { data in
            CachedCourse(
                id: data.normalizedKey,
                displayName: data.displayName,
                totalHoles: data.totalHoles,
                holePars: data.holePars,
                lastPlayedDate: data.lastPlayedDate,
                playCount: data.playCount
            )
        }.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        
        courses = cached
        normalizedLookup = Dictionary(uniqueKeysWithValues: cached.map { ($0.id, $0) })
        
        persistToUserDefaults()
    }
    
    func coursesMatching(query: String) -> [CachedCourse] {
        let normalized = Self.normalizeCourseName(query)
        guard !normalized.isEmpty else { return [] }
        
        return courses.filter { course in
            course.normalizedKey.contains(normalized)
        }
    }
    
    func updateCourseTemplate(courseName: String, totalHoles: Int, holePars: [Int]) {
        let key = Self.normalizeCourseName(courseName)
        guard !key.isEmpty, var course = normalizedLookup[key] else { return }
        
        course.displayName = courseName
        course.totalHoles = totalHoles
        course.holePars = holePars
        course.lastPlayedDate = Self.todayYMD()
        
        if let index = courses.firstIndex(where: { $0.id == key }) {
            courses[index] = course
            normalizedLookup[key] = course
            persistToUserDefaults()
        }
    }
    
    static func normalizeCourseName(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    
    private static func todayYMD() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: Date()).prefix(10).description
    }
    
    private struct CourseData {
        let normalizedKey: String
        var displayName: String
        var totalHoles: Int
        var holePars: [Int]
        var lastPlayedDate: String
        var playCount: Int
    }
    
    private func persistToUserDefaults() {
        let encoded = courses.map { course in
            [
                "id": course.id,
                "displayName": course.displayName,
                "totalHoles": String(course.totalHoles),
                "holePars": course.holePars.map(String.init).joined(separator: ","),
                "lastPlayedDate": course.lastPlayedDate,
                "playCount": String(course.playCount)
            ]
        }
        UserDefaults.standard.set(try? JSONSerialization.data(withJSONObject: encoded), forKey: "courseCacheV1")
    }
    
    func restoreFromUserDefaults() {
        guard let data = UserDefaults.standard.data(forKey: "courseCacheV1"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: String]]
        else { return }
        
        courses = json.compactMap { dict -> CachedCourse? in
            guard let id = dict["id"],
                  let displayName = dict["displayName"],
                  let totalHolesStr = dict["totalHoles"],
                  let totalHoles = Int(totalHolesStr),
                  let holeParsStr = dict["holePars"],
                  let lastPlayedDate = dict["lastPlayedDate"],
                  let playCountStr = dict["playCount"],
                  let playCount = Int(playCountStr)
            else { return nil }
            
            let holePars = holeParsStr.split(separator: ",").compactMap { Int($0) }
            
            return CachedCourse(
                id: id,
                displayName: displayName,
                totalHoles: totalHoles,
                holePars: holePars,
                lastPlayedDate: lastPlayedDate,
                playCount: playCount
            )
        }
        
        normalizedLookup = Dictionary(uniqueKeysWithValues: courses.map { ($0.id, $0) })
    }
}
