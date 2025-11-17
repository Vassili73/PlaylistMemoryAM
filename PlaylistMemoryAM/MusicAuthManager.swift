import Foundation
import MusicKit
import Combine

class MusicAuthManager: ObservableObject {
    
    @Published var isAuthorized = false
    
    init() {
        Task { await refreshAuthorizationStatus() }
    }
    
    func refreshAuthorizationStatus() async {
        let status = await MusicAuthorization.currentStatus
        await MainActor.run {
            self.isAuthorized = (status == .authorized)
        }
    }
    
    func requestAuthorization() async {
        let status = await MusicAuthorization.request()
        await MainActor.run {
            self.isAuthorized = (status == .authorized)
        }
    }
}
