import SwiftUI

/// Wire this into the host app TabView as a new entry point.
struct LocalTimeClockTabView: View {
    var body: some View {
        TimeClockRootView()
            .tabItem {
                Label("Time Clock", systemImage: "clock.badge")
            }
    }
}
