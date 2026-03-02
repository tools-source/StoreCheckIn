import SwiftUI

/// Wire this into the host TabView as a new entry point.
/// Example: `LocalTimeClockTabView()`
struct LocalTimeClockTabView: View {
    var body: some View {
        EmployeesView()
            .tabItem {
                Label("Time Clock", systemImage: "clock.badge")
            }
    }
}
