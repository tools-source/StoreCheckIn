import SwiftUI
import SwiftData

struct EmployeesView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var authController: AppAuthController
    @EnvironmentObject private var storeProfileController: StoreProfileController
    @Query(sort: \Employee.createdAt, order: .reverse) private var employees: [Employee]

    @Binding var selectedTab: LocalTimeClockTabView.Tab
    @State private var navigationPath: [UUID] = []
    @State private var showAddEmployee = false
    @State private var showArchiveAllConfirmation = false
    @State private var showArchiveBlockedAlert = false
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
            .navigationTitle(storeProfileController.employeesTitle)
            .navigationDestination(for: UUID.self) { employeeID in
                if let employee = visibleEmployees.first(where: { $0.id == employeeID }) {
                    EmployeeDetailView(employee: employee, scope: .active)
                } else {
                    Text("Employee not found")
                        .foregroundStyle(.secondary)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Archive") {
                        handleArchiveButtonTap()
                    }
                    .disabled(archiveableEmployees.isEmpty)
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
        .task(id: legacyArchiveSignature) {
            ArchiveStore.migrateLegacySnapshots(for: employees, ownerUserID: currentUserID, context: context)
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
        .alert("Archive all employees?", isPresented: $showArchiveAllConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Archive Employees", role: .destructive) {
                archiveAllEmployees()
            }
        } message: {
            Text("This copies employee hours into Archive and clears those hours from the Employees tab. Employees stay on the Employees tab.")
        }
        .alert("Check out employees first", isPresented: $showArchiveBlockedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Employees who are still checked in need to be checked out before they can be archived.")
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

    private func handleArchiveButtonTap() {
        if archiveableEmployees.contains(where: { $0.openEntry != nil }) {
            showArchiveBlockedAlert = true
            return
        }

        showArchiveAllConfirmation = true
    }

    private func archiveAllEmployees() {
        guard !archiveableEmployees.isEmpty else { return }

        for employee in archiveableEmployees {
            for entry in ArchiveStore.activeEntries(for: employee) {
                entry.isArchived = true
            }
        }

        try? context.save()
        selectedTab = .archive
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
        return employees.filter { $0.ownerUserID == currentUserID && $0.sourceEmployeeID == nil }
    }

    private var archiveableEmployees: [Employee] {
        visibleEmployees.filter { ArchiveStore.hasActiveEntries(for: $0) }
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

    private var legacyArchiveSignature: String {
        employees
            .filter { $0.ownerUserID == currentUserID }
            .map {
                [
                    $0.id.uuidString,
                    $0.isArchived.description,
                    $0.sourceEmployeeID?.uuidString ?? "none",
                    String($0.entriesList.count)
                ].joined(separator: ":")
            }
            .joined(separator: "|")
    }
}
