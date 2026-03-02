import SwiftUI
import SwiftData

struct EmployeesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Employee.createdAt, order: .reverse) private var employees: [Employee]
    @Query(sort: \TimeEntry.createdAt, order: .reverse) private var allEntries: [TimeEntry]
    @StateObject private var viewModel = EmployeeListViewModel()

    @State private var showingAdd = false
    @State private var showingClearAllConfirm = false
    @State private var showingClearAllDoubleConfirm = false

    @State private var newName = ""
    @State private var newRole = ""
    @State private var newRate = "20.00"
    @State private var newNotes = ""
    @State private var newIsActive = true

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.filteredEmployees(employees).isEmpty {
                    ContentUnavailableView {
                        Label("No Employees Yet", systemImage: "person.3.sequence")
                    } description: {
                        Text("Add your first employee to start local check-ins and timesheets.")
                    } actions: {
                        Button("Add Employee") { showingAdd = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: LocalTimeClockConstants.spacingM) {
                            ForEach(viewModel.filteredEmployees(employees)) { employee in
                                NavigationLink {
                                    EmployeeDetailView(employee: employee)
                                } label: {
                                    EmployeeRowView(employee: employee) {
                                        viewModel.checkIn(employee: employee, context: context)
                                        Haptics.success()
                                    } onCheckOut: {
                                        viewModel.checkOut(employee: employee, context: context)
                                        Haptics.success()
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, LocalTimeClockConstants.spacingL)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Employees")
            .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) {
                        showingClearAllConfirm = true
                    } label: {
                        Label("Clear All Data", systemImage: "trash")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                EmployeeFormView(
                    title: "Add Employee",
                    name: $newName,
                    role: $newRole,
                    hourlyRate: $newRate,
                    notes: $newNotes,
                    isActive: $newIsActive
                ) {
                    let employee = Employee(
                        name: newName.trimmingCharacters(in: .whitespacesAndNewlines),
                        roleOrTitle: newRole.nilIfBlank,
                        hourlyRate: Decimal(string: newRate) ?? 0,
                        notes: newNotes.nilIfBlank,
                        isActive: newIsActive
                    )
                    context.insert(employee)
                    try? context.save()
                    resetAddForm()
                }
            }
            .alert("Clear all local data?", isPresented: $showingClearAllConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Continue", role: .destructive) { showingClearAllDoubleConfirm = true }
            } message: {
                Text("This will remove all employees and all time entries from this device.")
            }
            .alert("This action cannot be undone", isPresented: $showingClearAllDoubleConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Everything", role: .destructive) {
                    viewModel.clearAllData(context: context, employees: employees, entries: allEntries)
                }
            } message: {
                Text("Are you absolutely sure you want to permanently delete all local time clock data?")
            }
        }
    }

    private func resetAddForm() {
        newName = ""
        newRole = ""
        newRate = "20.00"
        newNotes = ""
        newIsActive = true
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
