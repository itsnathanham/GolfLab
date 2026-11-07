import Foundation

enum ActiveRoundLink {
    static let url = URL(string: "golflab://round")!

    static func matches(_ url: URL) -> Bool {
        url.scheme == "golflab" && url.host == "round"
    }
}
