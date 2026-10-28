import ActivityKit

nonisolated struct BlockAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        var current: String?
        var blocked: Int
        var cap: Int?
        var isFinished: Bool
    }

    var platform: String
}
