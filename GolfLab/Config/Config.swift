import Foundation

enum Config {
    static let supabaseURL: String = {
        string(forInfoKey: "GLSupabaseURL", hint: "Set SUPABASE_URL in GolfLab/Config/Secrets.local.xcconfig (see Secrets.local.example.xcconfig).")
    }()

    static let supabaseAnonKey: String = {
        string(forInfoKey: "GLSupabaseAnonKey", hint: "Set SUPABASE_ANON_KEY in GolfLab/Config/Secrets.local.xcconfig (see Secrets.local.example.xcconfig).")
    }()

    private static func string(forInfoKey key: String, hint: String) -> String {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            fatalError("Missing \(key). \(hint)")
        }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains("YOUR_") else {
            fatalError("Invalid or placeholder \(key). \(hint)")
        }
        return value
    }
}
