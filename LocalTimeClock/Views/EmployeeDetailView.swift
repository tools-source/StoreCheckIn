import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct EmployeeDetailView: View {
    enum Scope {
        case active
        case archived
    }

    private enum ArchiveFilter: String, CaseIterable, Identifiable {
        case allTime
        case weekly

        var id: Self { self }

        var title: String {
            switch self {
            case .allTime:
                return "All Time"
            case .weekly:
                return "Weekly"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let employee: Employee
    let scope: Scope

    @State private var now: Date = .now
    @State private var archiveFilter: ArchiveFilter = .allTime
    @State private var selectedWeekAnchor: Date = .now
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

            if scope == .archived {
                archivedFilterSection
            }

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
                        title: scope == .archived ? "No Archived Entries" : "No Time Entries",
                        subtitle: scope == .archived
                            ? archivedEmptyStateSubtitle
                            : "Check this employee in and out to create entries.",
                        buttonTitle: scope == .archived ? "Back" : "Check In Now",
                        systemImage: scope == .archived ? "archivebox" : "clock.arrow.circlepath"
                    ) {
                        if scope == .archived {
                            dismiss()
                        } else {
                            checkInIfNeeded()
                        }
                    }
                    .listRowBackground(Color.clear)
                } else {
                    timesheetTable
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
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
                allEntries.forEach(context.delete)
                try? context.save()
            }
        }
        .onReceive(timer) { now = $0 }
    }

    private var completedEntries: [TimeEntry] {
        allEntries.filter { $0.checkOutAt != nil }
    }

    private var allEntries: [TimeEntry] {
        switch scope {
        case .active:
            ArchiveStore.activeEntries(for: employee)
        case .archived:
            ArchiveStore.archivedEntries(for: employee, in: selectedArchiveInterval)
        }
    }

    private var archivedEmptyStateSubtitle: String {
        guard let selectedArchiveInterval else {
            return "Archive employee hours from the Employees tab to see them here."
        }

        return "No archived entries for \(Formatters.readableDateRange(selectedArchiveInterval))."
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

                if scope == .archived, let selectedArchiveInterval {
                    Label("Range: \(Formatters.readableDateRange(selectedArchiveInterval))", systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    summaryCard(title: "Entries", value: "\(allEntries.count)")
                    summaryCard(title: "Total Worked", value: Formatters.hhmmss(seconds: totalSeconds), monospaced: true)
                    summaryCard(title: "Total Pay", value: Formatters.currency(totalPay), tint: .blue)

                    if scope == .active, let open = employee.openEntry {
                        summaryCard(
                            title: "Live Timer",
                            value: Formatters.hhmmss(seconds: now.timeIntervalSince(open.checkInAt)),
                            tint: .green,
                            monospaced: true
                        )
                    } else {
                        summaryCard(
                            title: "Status",
                            value: scope == .archived ? "Archived History" : (employee.isActive ? "Active" : "Inactive"),
                            tint: scope == .archived ? .blue : (employee.isActive ? .green : .secondary)
                        )
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var archivedFilterSection: some View {
        Section("Archive Range") {
            Picker("Archive Range", selection: $archiveFilter) {
                ForEach(ArchiveFilter.allCases) { filter in
                    Text(filter.title)
                        .tag(filter)
                }
            }
            .pickerStyle(.segmented)

            if archiveFilter == .weekly, let selectedArchiveInterval {
                HStack(spacing: 12) {
                    archiveWeekButton(systemImage: "chevron.left") {
                        shiftSelectedWeek(by: -1)
                    }

                    Spacer()

                    VStack(spacing: 4) {
                        Text("Pay Week")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(Formatters.readableDateRange(selectedArchiveInterval))
                            .font(.subheadline.weight(.semibold))
                    }

                    Spacer()

                    archiveWeekButton(systemImage: "chevron.right") {
                        shiftSelectedWeek(by: 1)
                    }
                    .disabled(!canMoveToNextWeek)
                }
                .padding(.top, 4)
            }
        }
    }

    private func archiveWeekButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var selectedArchiveInterval: DateInterval? {
        guard scope == .archived, archiveFilter == .weekly else { return nil }
        return Calendar.current.dateInterval(of: .weekOfYear, for: selectedWeekAnchor)
    }

    private func shiftSelectedWeek(by offset: Int) {
        guard let newDate = Calendar.current.date(byAdding: .weekOfYear, value: offset, to: selectedWeekAnchor) else {
            return
        }

        selectedWeekAnchor = newDate
    }

    private var canMoveToNextWeek: Bool {
        guard let selectedArchiveInterval,
              let currentWeekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: .now)
        else {
            return false
        }

        return selectedArchiveInterval.start < currentWeekInterval.start
    }

    private var timesheetTable: some View {
        VStack(spacing: 0) {
            timesheetHeaderRow

            ForEach(allEntries) { entry in
                Divider()
                    .overlay(Color(.separator).opacity(0.18))
                timesheetRow(entry)
                    .background(rowBackground(for: entry))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(.separator).opacity(0.18), lineWidth: 1)
        )
    }

    private var timesheetHeaderRow: some View {
        HStack(spacing: 8) {
            tableHeader("Date")
                .frame(maxWidth: .infinity, alignment: .leading)
            tableHeader("In")
                .frame(width: 62, alignment: .leading)
            tableHeader("Out")
                .frame(width: 62, alignment: .leading)
            tableHeader("Total", alignment: .trailing)
                .frame(width: 84, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func timesheetRow(_ entry: TimeEntry) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entryWeekday(for: entry))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(entryMonthDay(for: entry))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            tableValue(Formatters.time(entry.checkInAt))
                .frame(width: 62, alignment: .leading)

            tableValue(entry.checkOutAt.map(Formatters.time) ?? "Open", color: outTextColor(for: entry))
                .frame(width: 62, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatters.hhmmss(seconds: workedSeconds(for: entry)))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(primaryValueColor(for: entry))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(Formatters.currency(pay(for: entry)))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.blue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(width: 84, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func tableHeader(_ title: String, alignment: Alignment = .leading) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    private func tableValue(_ text: String, color: Color = .primary) -> some View {
        Text(text)
            .font(.caption.monospacedDigit())
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    private func entryWeekday(for entry: TimeEntry) -> String {
        entry.checkInAt.formatted(.dateTime.weekday(.abbreviated))
    }

    private func entryMonthDay(for entry: TimeEntry) -> String {
        entry.checkInAt.formatted(.dateTime.month(.defaultDigits).day())
    }

    private func outTextColor(for entry: TimeEntry) -> Color {
        entry.checkOutAt == nil ? .green : .primary
    }

    private func primaryValueColor(for entry: TimeEntry) -> Color {
        entry.checkOutAt == nil ? .green : .primary
    }

    private func rowBackground(for entry: TimeEntry) -> Color {
        if entry.checkOutAt == nil {
            return Color.green.opacity(0.08)
        }

        if scope == .archived {
            return Color.blue.opacity(0.04)
        }

        return .clear
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
        guard scope == .active else { return }
        guard employee.openEntry == nil else { return }
        context.insert(TimeEntry(ownerUserID: employee.ownerUserID, employee: employee, checkInAt: .now))
        try? context.save()
        Haptics.success()
    }
}
