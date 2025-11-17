import Foundation
import MusicKit
import Combine

class MusicAuthManager: ObservableObject {
    
    @Published var isAuthorized = false
    
    func requestAuthorization() async {
        let status = await MusicAuthorization.request()
        DispatchQueue.main.async {
            self.isAuthorized = (status == .authorized)
        }
    }
}
