import SwiftUI
import SwiftData

struct ArchiveView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Employee.createdAt, order: .reverse) private var employees: [Employee]

    let currentUserID: String?
    @Binding var selectedTab: LocalTimeClockTabView.Tab

    @State private var navigationPath: [UUID] = []
    @State private var showClearAll = false
    @State private var showClearAllAgain = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            archiveList
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Archive")
                .navigationDestination(for: UUID.self, destination: archiveDestination)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") {
                            showClearAll = true
                        }
                        .disabled(totalEntryCount == 0)
                    }
                }
                .alert("Clear all archived time clock data?", isPresented: $showClearAll) {
                    Button("Cancel", role: .cancel) {}
                    Button("Continue", role: .destructive) {
                        showClearAllAgain = true
                    }
                } message: {
                    Text("This clears all archived employee check-in and check-out history.")
                }
                .alert("Final confirmation", isPresented: $showClearAllAgain) {
                    Button("Cancel", role: .cancel) {}
                    Button("Clear Time Entries", role: .destructive) {
                        clearArchivedTimeEntries()
                    }
                } message: {
                    Text("Employees will stay on both tabs. Only archived check-in and check-out records will be removed.")
                }
        }
        .task(id: legacyArchiveSignature) {
            ArchiveStore.migrateLegacySnapshots(for: employees, ownerUserID: currentUserID, context: context)
        }
    }

    private var archiveList: some View {
        List {
            archiveRows
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var archiveRows: some View {
        if archivedEmployees.isEmpty {
            EmptyStateView(
                title: "No Archived Hours",
                subtitle: "Employee hours that you archive from the Employees tab will show up here.",
                buttonTitle: "Employees",
                systemImage: "archivebox"
            ) {
                selectedTab = .employees
            }
            .listRowInsets(EdgeInsets(top: 20, leading: 16, bottom: 6, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        } else {
            ForEach(archivedEmployees) { employee in
                archiveEmployeeRow(employee)
            }
        }
    }

    private func archiveEmployeeRow(_ employee: Employee) -> some View {
        NavigationLink(value: employee.id) {
            ArchiveEmployeeCardView(
                employee: employee,
                archivedEntries: ArchiveStore.archivedEntries(for: employee)
            )
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func archiveDestination(for employeeID: UUID) -> some View {
        if let employee = liveEmployees.first(where: { $0.id == employeeID }) {
            EmployeeDetailView(employee: employee, scope: .archived)
        } else {
            Text("Employee not found")
                .foregroundStyle(.secondary)
        }
    }

    private var archivedEmployees: [Employee] {
        liveEmployees
            .filter { ArchiveStore.hasArchivedEntries(for: $0) }
            .sorted { archiveSortDate(for: $0) > archiveSortDate(for: $1) }
    }

    private var liveEmployees: [Employee] {
        guard let currentUserID else { return [] }
        return employees.filter { $0.ownerUserID == currentUserID && $0.sourceEmployeeID == nil }
    }

    private var totalEntryCount: Int {
        archivedEmployees.reduce(into: 0) { partialResult, employee in
            partialResult += ArchiveStore.archivedEntries(for: employee).count
        }
    }

    private func archiveSortDate(for employee: Employee) -> Date {
        ArchiveStore.archivedEntries(for: employee).map { $0.checkOutAt ?? $0.checkInAt }.max() ?? employee.createdAt
    }

    private func clearArchivedTimeEntries() {
        archivedEmployees
            .flatMap { ArchiveStore.archivedEntries(for: $0) }
            .forEach(context.delete)

        try? context.save()
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

private struct ArchiveEmployeeCardView: View {
    let employee: Employee
    let archivedEntries: [TimeEntry]

    private var entryCount: Int {
        archivedEntries.count
    }

    private var completedEntries: [TimeEntry] {
        archivedEntries.filter { $0.checkOutAt != nil }
    }

    private var totalSeconds: TimeInterval {
        Formatters.workedSeconds(for: completedEntries)
    }

    private var totalPay: Double {
        Formatters.pay(seconds: totalSeconds, hourlyRate: employee.hourlyRate)
    }

    private var lastActivityDate: Date? {
        archivedEntries.map { $0.checkOutAt ?? $0.checkInAt }.max()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(employee.name)
                        .font(.headline)

                    if let role = employee.roleOrTitle, !role.isEmpty {
                        Text(role)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
                statusBadge
            }

            HStack {
                Text("\(entryCount) \(entryCount == 1 ? "Entry" : "Entries")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("Worked: \(Formatters.hhmmss(seconds: totalSeconds))")
                    .font(.caption.monospacedDigit())
            }

            if let lastActivityDate {
                Label("Last activity \(Formatters.readableDateTime(lastActivityDate))", systemImage: "calendar.badge.clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Pay: \(Formatters.currency(totalPay))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Label("View Timesheet", systemImage: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color(.secondarySystemBackground), Color(.tertiarySystemBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var statusBadge: some View {
        Text("Archived Hours")
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.16))
            .foregroundStyle(Color.blue)
            .clipShape(Capsule())
    }
}
