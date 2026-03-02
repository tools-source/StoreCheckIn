import SwiftUI
import SwiftData

struct EmployeesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Employee.createdAt, order: .reverse) private var employees: [Employee]

    @State private var showAddEmployee = false
    @State private var showClearAll = false
    @State private var showClearAllAgain = false

    var body: some View {
        NavigationStack {
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
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(employees) { employee in
                                NavigationLink {
                                    EmployeeDetailView(employee: employee)
                                } label: {
                                    EmployeeCardView(employee: employee) {
                                        checkIn(employee)
                                    } onCheckOut: {
                                        checkOut(employee)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Employees")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear All", role: .destructive) {
                        showClearAll = true
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
        .alert("Clear all time clock data?", isPresented: $showClearAll) {
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .destructive) {
                showClearAllAgain = true
            }
        } message: {
            Text("This deletes all employees and all entries.")
        }
        .alert("Final confirmation", isPresented: $showClearAllAgain) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This action cannot be undone.")
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

    private func clearAllData() {
        do {
            let allEmployees = try context.fetch(FetchDescriptor<Employee>())
            allEmployees.forEach(context.delete)

            let allEntries = try context.fetch(FetchDescriptor<TimeEntry>())
            allEntries.forEach(context.delete)

            try context.save()
        } catch {
            assertionFailure("Failed to clear all data: \(error)")
        }
    }
}
