import SwiftUI

@main
struct AIImageGenApp: App {
    @StateObject private var config = AppConfig()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(config)
                .preferredColorScheme(.dark)
        }
    }
}
