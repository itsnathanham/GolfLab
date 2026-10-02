import Foundation

enum Config {
    static var supabaseURL: String? {
        optionalString(forInfoKey: "GLSupabaseURL")
    }

    static var supabaseAnonKey: String? {
        optionalString(forInfoKey: "GLSupabaseAnonKey")
    }

    static var hasSupabaseCredentials: Bool {
        supabaseURL != nil && supabaseAnonKey != nil
    }

    private static func optionalString(forInfoKey key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        let hasUnresolvedBuildSetting = value.contains("$(") || value.contains("${")
        guard !value.isEmpty, !value.contains("YOUR_"), !hasUnresolvedBuildSetting else { return nil }
        return value
    }
}
