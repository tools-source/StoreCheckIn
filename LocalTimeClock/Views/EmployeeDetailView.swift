import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct EmployeeDetailView: View {
    @Environment(\.modelContext) private var context

    let employee: Employee

    @State private var now: Date = .now
    @State private var showEdit = false
    @State private var showClearTimesheet = false
    @State private var showExporter = false
    @State private var exportDocument = CSVDocument(text: "")
    @State private var exportFilename = "Timesheet"
    @State private var justCopiedTimesheet = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        List {
            headerSection

            Section("Actions") {
                Button {
                    copyTimesheet()
                } label: {
                    Label(
                        justCopiedTimesheet ? "Copied to Clipboard" : "Copy Timesheet as Text",
                        systemImage: justCopiedTimesheet ? "checkmark.circle.fill" : "doc.on.doc"
                    )
                    .foregroundStyle(justCopiedTimesheet ? Color.green : Color.primary)
                }

                Button("Export CSV") {
                    let export = Exporters.makeCSVExport(
                        employee: employee,
                        entries: completedEntries,
                        totalSeconds: totalSeconds,
                        totalPay: totalPay
                    )
                    exportDocument = export.document
                    exportFilename = export.filename
                    showExporter = true
                }

                Button("Clear Timesheet", role: .destructive) {
                    showClearTimesheet = true
                }
            }

            Section("Timesheet") {
                if allEntries.isEmpty {
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
                    timesheetTable
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
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
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: exportFilename
        ) { _ in }
        .alert("Clear this employee's timesheet?", isPresented: $showClearTimesheet) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                employee.entriesList.forEach(context.delete)
                try? context.save()
            }
        }
        .onReceive(timer) { now = $0 }
    }

    private var completedEntries: [TimeEntry] {
        allEntries.filter { $0.checkOutAt != nil }
    }

    private var allEntries: [TimeEntry] {
        employee.sortedEntriesNewestFirst
    }

    private var totalSeconds: TimeInterval {
        Formatters.workedSeconds(for: completedEntries)
    }

    private var totalPay: Double {
        Formatters.pay(seconds: totalSeconds, hourlyRate: employee.hourlyRate)
    }

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                Text(employee.roleOrTitle ?? "No role/title")
                    .foregroundStyle(.secondary)

                if let shiftSummary = employee.shiftSummary {
                    Label("Shift: \(shiftSummary)", systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    summaryCard(title: "Entries", value: "\(allEntries.count)")
                    summaryCard(title: "Total Worked", value: Formatters.hhmmss(seconds: totalSeconds), monospaced: true)
                    summaryCard(title: "Total Pay", value: Formatters.currency(totalPay), tint: .blue)

                    if let open = employee.openEntry {
                        summaryCard(
                            title: "Live Timer",
                            value: Formatters.hhmmss(seconds: now.timeIntervalSince(open.checkInAt)),
                            tint: .green,
                            monospaced: true
                        )
                    } else {
                        summaryCard(title: "Status", value: employee.isActive ? "Active" : "Inactive", tint: employee.isActive ? .green : .secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var timesheetTable: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                timesheetHeaderRow

                ForEach(allEntries) { entry in
                    Divider()
                    timesheetRow(entry)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.separator).opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    private var timesheetHeaderRow: some View {
        HStack(spacing: 12) {
            tableHeader("Day", width: 104)
            tableHeader("In", width: 82)
            tableHeader("Out", width: 82)
            tableHeader("Hours", width: 92, alignment: .trailing)
            tableHeader("Pay", width: 96, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func timesheetRow(_ entry: TimeEntry) -> some View {
        HStack(spacing: 12) {
            tableCell(Formatters.day(entry.checkInAt), width: 104)
            tableCell(Formatters.time(entry.checkInAt), width: 82, monospaced: true)
            tableCell(
                entry.checkOutAt.map(Formatters.time) ?? "Open",
                width: 82,
                color: entry.checkOutAt == nil ? .green : .primary,
                monospaced: true
            )
            tableCell(
                Formatters.hhmmss(seconds: workedSeconds(for: entry)),
                width: 92,
                alignment: .trailing,
                monospaced: true
            )
            tableCell(
                Formatters.currency(pay(for: entry)),
                width: 96,
                alignment: .trailing,
                color: entry.checkOutAt == nil ? .green : .primary,
                monospaced: true
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(entry.checkOutAt == nil ? Color.green.opacity(0.08) : Color.clear)
    }

    private func tableHeader(_ title: String, width: CGFloat, alignment: Alignment = .leading) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: alignment)
            .textCase(.uppercase)
    }

    private func tableCell(
        _ text: String,
        width: CGFloat,
        alignment: Alignment = .leading,
        color: Color = .primary,
        monospaced: Bool = false
    ) -> some View {
        Text(text)
            .font(monospaced ? .subheadline.monospacedDigit() : .subheadline)
            .foregroundStyle(color)
            .frame(width: width, alignment: alignment)
    }

    private func summaryCard(
        title: String,
        value: String,
        tint: Color = .primary,
        monospaced: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(monospaced ? .headline.monospacedDigit() : .headline)
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func workedSeconds(for entry: TimeEntry) -> TimeInterval {
        entry.durationSeconds ?? max(0, now.timeIntervalSince(entry.checkInAt))
    }

    private func pay(for entry: TimeEntry) -> Double {
        Formatters.pay(seconds: workedSeconds(for: entry), hourlyRate: employee.hourlyRate)
    }

    private func copyTimesheet() {
        Exporters.copyTimesheet(employee: employee, entries: completedEntries, totalSeconds: totalSeconds, totalPay: totalPay)
        Haptics.success()

        withAnimation(.easeInOut(duration: 0.2)) {
            justCopiedTimesheet = true
        }

        Task {
            try? await Task.sleep(for: .seconds(1.6))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    justCopiedTimesheet = false
                }
            }
        }
    }

    private func checkInIfNeeded() {
        guard employee.openEntry == nil else { return }
        context.insert(TimeEntry(ownerUserID: employee.ownerUserID, employee: employee, checkInAt: .now))
        try? context.save()
        Haptics.success()
    }
}
