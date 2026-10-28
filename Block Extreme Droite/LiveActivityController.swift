import ActivityKit

/// Mirrors a run on the lock screen and Dynamic Island. Every call is a no-op when no activity is running.
@MainActor
final class LiveActivityController {
    private var activity: Activity<BlockAttributes>?
    private var cap: Int?

    /// A run never survives the app being relaunched, so an activity left over from one is stale.
    static func endStale() async {
        for stale in Activity<BlockAttributes>.activities { await stale.end(nil, dismissalPolicy: .immediate) }
    }

    func start(platform: Platform, cap: Int?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        self.cap = cap
        let state = BlockAttributes.ContentState(current: nil, blocked: 0, cap: cap, isFinished: false)
        activity = try? Activity.request(
            attributes: BlockAttributes(platform: platform.label),
            content: .init(state: state, staleDate: nil)
        )
    }

    func update(current: String?, blocked: Int) {
        guard let activity else { return }
        let state = BlockAttributes.ContentState(current: current, blocked: blocked, cap: cap, isFinished: false)
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    func end(blocked: Int) {
        guard let activity else { return }
        self.activity = nil
        let state = BlockAttributes.ContentState(current: nil, blocked: blocked, cap: cap, isFinished: true)
        Task { await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .default) }
    }
}
