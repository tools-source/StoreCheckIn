import SwiftUI
import SwiftData

struct EmployeesView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var authController: AppAuthController
    @EnvironmentObject private var subscriptionController: SubscriptionController
    @Query(sort: \Employee.createdAt, order: .reverse) private var employees: [Employee]

    @State private var navigationPath: [UUID] = []
    @State private var showAddEmployee = false
    @State private var showClearAll = false
    @State private var showClearAllAgain = false
    @State private var employeeToEdit: Employee?
    @State private var employeeToDelete: Employee?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if employees.isEmpty {
                    EmptyStateView(
                        title: "No Employees",
                        subtitle: "Add an employee to start tracking local check-ins and payroll totals.",
                        buttonTitle: "Add Employee",
                        systemImage: "person.badge.plus"
                    ) {
                        showAddEmployee = true
                    }
                } else {
                    List {
                        ForEach(employees) { employee in
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
                if let employee = employees.first(where: { $0.id == employeeID }) {
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
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                openURL(url)
                            }
                        }
                        Divider()
                        Button("Clear All Time Entries", role: .destructive) {
                            showClearAll = true
                        }
                        Button("Sign Out", role: .destructive) {
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
            EditEmployeeView(title: "Add Employee") { name, role, rate, notes, isActive in
                let employee = Employee(name: name, roleOrTitle: role, hourlyRate: rate, notes: notes, isActive: isActive)
                context.insert(employee)
                try? context.save()
            }
        }
        .sheet(item: $employeeToEdit) { employee in
            EditEmployeeView(employee: employee, title: "Edit Employee") { name, role, rate, notes, isActive in
                employee.name = name
                employee.roleOrTitle = role
                employee.hourlyRate = rate
                employee.notes = notes
                employee.isActive = isActive
                try? context.save()
            }
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
        guard employee.openEntry == nil else { return }
        context.insert(TimeEntry(employee: employee, checkInAt: .now))
        try? context.save()
        Haptics.success()
    }

    private func checkOut(_ employee: Employee) {
        guard let openEntry = employee.openEntry else { return }
        openEntry.checkOutAt = .now
        try? context.save()
        Haptics.success()
    }

    private func delete(_ employee: Employee) {
        context.delete(employee)
        try? context.save()
    }

    private func clearAllTimeEntries() {
        do {
            let allEntries = try context.fetch(FetchDescriptor<TimeEntry>())
            allEntries.forEach(context.delete)

            try context.save()
        } catch {
            assertionFailure("Failed to clear all time entries: \(error)")
        }
    }

    private var deleteAlertPresented: Binding<Bool> {
        Binding(
            get: { employeeToDelete != nil },
            set: { if !$0 { employeeToDelete = nil } }
        )
    }
}
