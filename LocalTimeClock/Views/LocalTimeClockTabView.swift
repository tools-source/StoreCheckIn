import SwiftUI

struct LocalTimeClockTabView: View {
    @EnvironmentObject private var authController: AppAuthController
    @State private var selectedTab: Tab = .employees

    enum Tab: Hashable {
        case employees
        case archive
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            EmployeesView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Employees", systemImage: "person.3.fill")
                }
                .tag(Tab.employees)

            ArchiveView(currentUserID: authController.session?.userID, selectedTab: $selectedTab)
                .tabItem {
                    Label("Archive", systemImage: "archivebox.fill")
                }
                .tag(Tab.archive)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
        }
    }
}
