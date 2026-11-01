import Observation

@MainActor
@Observable
final class AppRouter {
    enum Tab: Hashable {
        case add
        case queue
        case library
    }

    var selectedTab: Tab = .add
}
