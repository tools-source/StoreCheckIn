import SwiftUI
import SwiftData

struct EmployeesView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var authController: AppAuthController
    @EnvironmentObject private var subscriptionController: SubscriptionController
    @Query(sort: \Employee.createdAt, order: .reverse) private var employees: [Employee]
    private let subscriptionsURL = "https://apps.apple.com/account/subscriptions"
    private let privacyPolicyURL = "https://tools-source.github.io/StoreCheckIn/privacy.html"
    private let termsOfUseURL = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"

    @State private var navigationPath: [UUID] = []
    @State private var showAddEmployee = false
    @State private var showClearAll = false
    @State private var showClearAllAgain = false
    @State private var employeeToEdit: Employee?
    @State private var employeeToDelete: Employee?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if visibleEmployees.isEmpty {
                    EmptyStateView(
                        title: "No Employees",
                        subtitle: "Add an employee to start tracking check-ins and payroll totals for this account.",
                        buttonTitle: "Add Employee",
                        systemImage: "person.badge.plus"
                    ) {
                        showAddEmployee = true
                    }
                } else {
                    List {
                        ForEach(visibleEmployees) { employee in
                            EmployeeCardView(employee: employee) {
                                checkIn(employee)
                            } onCheckOut: {
                                checkOut(employee)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                navigationPath.append(employee.id)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    employeeToEdit = employee
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    employeeToDelete = employee
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Employees")
            .navigationDestination(for: UUID.self) { employeeID in
                if let employee = visibleEmployees.first(where: { $0.id == employeeID }) {
                    EmployeeDetailView(employee: employee)
                } else {
                    Text("Employee not found")
                        .foregroundStyle(.secondary)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Text(authController.accountSummary)
                        Text(authController.providerSummary)
                        Text(subscriptionController.statusSummary)
                        Button("Refresh Account Status") {
                            Task {
                                await authController.refreshSessionState()
                            }
                        }
                        Button("Restore Purchases") {
                            Task {
                                await subscriptionController.restorePurchases()
                            }
                        }
                        Button("Manage Subscription") {
                            openLink(subscriptionsURL)
                        }
                        Button("Privacy Policy") {
                            openLink(privacyPolicyURL)
                        }
                        Button("Terms of Use (EULA)") {
                            openLink(termsOfUseURL)
                        }
                        Divider()
                        Button("Clear All Time Entries", role: .destructive) {
                            showClearAll = true
                        }
                        Button("Sign Out", role: .destructive) {
                            Task {
                                await ShiftReminderScheduler.removeAllEmployeeReminders()
                            }
                            authController.signOut()
                        }
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddEmployee = true
                    } label: {
                        Label("Add Employee", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddEmployee) {
            EditEmployeeView(title: "Add Employee") { name, role, rate, shiftStartMinutes, shiftEndMinutes, notes, isActive in
                guard let currentUserID else { return }

                let employee = Employee(
                    ownerUserID: currentUserID,
                    name: name,
                    roleOrTitle: role,
                    hourlyRate: rate,
                    shiftStartMinutes: shiftStartMinutes,
                    shiftEndMinutes: shiftEndMinutes,
                    notes: notes,
                    isActive: isActive
                )
                context.insert(employee)
                try? context.save()
            }
        }
        .sheet(item: $employeeToEdit) { employee in
            EditEmployeeView(employee: employee, title: "Edit Employee") { name, role, rate, shiftStartMinutes, shiftEndMinutes, notes, isActive in
                employee.name = name
                employee.roleOrTitle = role
                employee.hourlyRate = rate
                employee.shiftStartMinutes = shiftStartMinutes
                employee.shiftEndMinutes = shiftEndMinutes
                employee.notes = notes
                employee.isActive = isActive
                try? context.save()
            }
        }
        .task(id: reminderSyncSignature) {
            await ShiftReminderScheduler.syncReminders(for: visibleEmployees, ownerUserID: currentUserID)
        }
        .alert("Clear all time clock data?", isPresented: $showClearAll) {
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .destructive) {
                showClearAllAgain = true
            }
        } message: {
            Text("This clears all employee check-in and check-out history.")
        }
        .alert("Delete employee?", isPresented: deleteAlertPresented) {
            Button("Cancel", role: .cancel) {
                employeeToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let employeeToDelete {
                    delete(employeeToDelete)
                }
                employeeToDelete = nil
            }
        } message: {
            Text("Delete \(employeeToDelete?.name ?? "this employee") and all time entries?")
        }
        .alert("Final confirmation", isPresented: $showClearAllAgain) {
            Button("Cancel", role: .cancel) {}
            Button("Clear Time Entries", role: .destructive) {
                clearAllTimeEntries()
            }
        } message: {
            Text("Employees will stay. Only their check-in and check-out records will be removed.")
        }
    }

    private func checkIn(_ employee: Employee) {
        guard employee.ownerUserID == currentUserID else { return }
        guard employee.openEntry == nil else { return }
        context.insert(TimeEntry(ownerUserID: employee.ownerUserID, employee: employee, checkInAt: .now))
        try? context.save()
        Haptics.success()
    }

    private func checkOut(_ employee: Employee) {
        guard employee.ownerUserID == currentUserID else { return }
        guard let openEntry = employee.openEntry else { return }
        openEntry.checkOutAt = .now
        try? context.save()
        Haptics.success()
    }

    private func delete(_ employee: Employee) {
        guard employee.ownerUserID == currentUserID else { return }
        context.delete(employee)
        try? context.save()
    }

    private func clearAllTimeEntries() {
        visibleEmployees
            .flatMap(\.entriesList)
            .forEach(context.delete)

        try? context.save()
    }

    private var deleteAlertPresented: Binding<Bool> {
        Binding(
            get: { employeeToDelete != nil },
            set: { if !$0 { employeeToDelete = nil } }
        )
    }

    private var currentUserID: String? {
        authController.session?.userID
    }

    private var visibleEmployees: [Employee] {
        guard let currentUserID else { return [] }
        return employees.filter { $0.ownerUserID == currentUserID }
    }

    private var reminderSyncSignature: String {
        visibleEmployees
            .map {
                [
                    $0.id.uuidString,
                    $0.name,
                    $0.isActive.description,
                    String($0.shiftStartMinutes ?? -1),
                    String($0.shiftEndMinutes ?? -1)
                ].joined(separator: ":")
            }
            .joined(separator: "|")
    }

    private func openLink(_ rawURL: String) {
        guard let url = URL(string: rawURL) else { return }
        openURL(url)
    }
}
