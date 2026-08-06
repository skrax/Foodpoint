import Observation

@Observable
class AppState {
    static let shared = AppState()
    
    private init() {}
    
    var locations: [String] = []
}
