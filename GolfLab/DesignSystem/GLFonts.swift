import SwiftUI
import UIKit

/// IBM Plex Sans (variable bundle) + IBM Plex Mono static faces. Falls back to system fonts if a face is missing.
enum GLFonts {
    private static let sansRegular = "IBMPlexSans-Regular"
    private static let sansMedium = "IBMPlexSans-Medium"
    private static let sansSemi = "IBMPlexSans-SemiBold"
    private static let monoMedium = "IBMPlexMono-Medium"
    private static let monoSemi = "IBMPlexMono-SemiBold"

    private static func customOrSystem(name: String, size: CGFloat, fallback: Font) -> Font {
        if UIFont(name: name, size: size) != nil {
            return Font.custom(name, fixedSize: size)
        }
        return fallback
    }

    static func sans(size: CGFloat, weight: Font.Weight) -> Font {
        let fallback = Font.system(size: size, weight: weight, design: .default)
        switch weight {
        case .bold, .heavy: return customOrSystem(name: sansSemi, size: size, fallback: fallback)
        case .semibold: return customOrSystem(name: sansSemi, size: size, fallback: fallback)
        case .medium: return customOrSystem(name: sansMedium, size: size, fallback: fallback)
        default: return customOrSystem(name: sansRegular, size: size, fallback: fallback)
        }
    }

    static func mono(size: CGFloat, weight: Font.Weight) -> Font {
        let fallback = Font.system(size: size, weight: weight, design: .monospaced)
        switch weight {
        case .bold, .heavy, .semibold: return customOrSystem(name: monoSemi, size: size, fallback: fallback)
        case .medium: return customOrSystem(name: monoMedium, size: size, fallback: fallback)
        default: return customOrSystem(name: monoMedium, size: size, fallback: fallback)
        }
    }
}
