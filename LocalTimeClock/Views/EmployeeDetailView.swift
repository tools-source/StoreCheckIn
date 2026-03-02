import SwiftUI
import SwiftData

struct EmployeeDetailView: View {
    @Environment(\.modelContext) private var context

    let employee: Employee

    @State private var now: Date = .now
    @State private var showEdit = false
    @State private var showClearTimesheet = false
    @State private var showExport = false
    @State private var exportURL: URL?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        List {
            headerSection

            Section("Actions") {
                Button("Copy Timesheet as Text") {
                    Exporters.copyTimesheet(employee: employee, entries: completedEntries, totalSeconds: totalSeconds, totalPay: totalPay)
                }

                Button("Export CSV") {
                    do {
                        exportURL = try Exporters.makeCSV(employee: employee, entries: completedEntries, totalSeconds: totalSeconds, totalPay: totalPay)
                        showExport = true
                    } catch {
                        exportURL = nil
                    }
                }

                Button("Clear Timesheet", role: .destructive) {
                    showClearTimesheet = true
                }
            }

            Section("Timesheet") {
                if employee.sortedEntriesNewestFirst.isEmpty {
                    EmptyStateView(
                        title: "No Time Entries",
                        subtitle: "Check this employee in and out to create entries.",
                        buttonTitle: "Check In Now",
                        systemImage: "clock.arrow.circlepath"
                    ) {
                        checkInIfNeeded()
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(employee.sortedEntriesNewestFirst) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Check In: \(Formatters.dateTime(entry.checkInAt))")
                            Text("Check Out: \(entry.checkOutAt.map(Formatters.dateTime) ?? "In progress")")
                                .foregroundStyle(.secondary)
                            Text("Duration: \(entry.durationSeconds.map { Formatters.hhmmss(seconds: $0) } ?? "In progress")")
                                .font(.caption.monospacedDigit())
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(employee.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditEmployeeView(employee: employee, title: "Edit Employee") { name, role, rate, notes, isActive in
                employee.name = name
                employee.roleOrTitle = role
                employee.hourlyRate = rate
                employee.notes = notes
                employee.isActive = isActive
                try? context.save()
            }
        }
        .sheet(isPresented: $showExport) {
            if let exportURL {
                ShareSheet(activityItems: [exportURL])
            }
        }
        .alert("Clear this employee's timesheet?", isPresented: $showClearTimesheet) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                employee.entries.forEach(context.delete)
                try? context.save()
            }
        }
        .onReceive(timer) { now = $0 }
    }

    private var completedEntries: [TimeEntry] {
        employee.sortedEntriesNewestFirst.filter { $0.checkOutAt != nil }
    }

    private var totalSeconds: TimeInterval {
        Formatters.workedSeconds(for: completedEntries)
    }

    private var totalPay: Double {
        Formatters.pay(seconds: totalSeconds, hourlyRate: employee.hourlyRate)
    }

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text(employee.roleOrTitle ?? "No role/title")
                    .foregroundStyle(.secondary)
                Text("Total Worked: \(Formatters.hhmmss(seconds: totalSeconds))")
                Text("Total Pay: \(Formatters.currency(totalPay))")
                if let open = employee.openEntry {
                    Text("Live Timer: \(Formatters.hhmmss(seconds: now.timeIntervalSince(open.checkInAt)))")
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.green)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func checkInIfNeeded() {
        guard employee.openEntry == nil else { return }
        context.insert(TimeEntry(employee: employee, checkInAt: .now))
        try? context.save()
        Haptics.success()
    }
}
