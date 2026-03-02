import SwiftUI
import SwiftData

struct EmployeeDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var employee: Employee

    @State private var selectedRange: QuickRange = .all
    @State private var showingEdit = false
    @State private var showingClearSheetConfirm = false
    @State private var showingExport = false
    @State private var exportPayload: ExportPayload?

    @State private var editName = ""
    @State private var editRole = ""
    @State private var editRate = ""
    @State private var editNotes = ""
    @State private var editActive = true

    var body: some View {
        ScrollView {
            VStack(spacing: LocalTimeClockConstants.spacingM) {
                headerCard
                timesheetCard
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(employee.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    loadEditableFields()
                    showingEdit = true
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            EmployeeFormView(
                title: "Edit Employee",
                name: $editName,
                role: $editRole,
                hourlyRate: $editRate,
                notes: $editNotes,
                isActive: $editActive
            ) {
                employee.name = editName
                employee.roleOrTitle = editRole.nilIfBlank
                employee.hourlyRate = Decimal(string: editRate) ?? employee.hourlyRate
                employee.notes = editNotes.nilIfBlank
                employee.isActive = editActive
                try? context.save()
            }
        }
        .sheet(isPresented: $showingExport) {
            if let exportPayload {
                ShareSheet(activityItems: [exportPayload.data, exportPayload.filename])
            }
        }
        .alert("Clear this employee's timesheet?", isPresented: $showingClearSheetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                employee.timeEntries.forEach(context.delete)
                try? context.save()
            }
        } message: {
            Text("Only this employee’s entries will be deleted.")
        }
    }

    private var filteredEntries: [TimeEntry] {
        let interval = selectedRange.dateInterval()
        return employee.sortedEntriesNewestFirst.filter { entry in
            guard let interval else { return true }
            if let out = entry.checkOutAt {
                return interval.contains(entry.checkInAt) || interval.contains(out)
            }
            return interval.contains(entry.checkInAt)
        }
    }

    private var totalSeconds: TimeInterval {
        TimeAndPayCalculator.totalWorkedSeconds(entries: filteredEntries)
    }

    private var totalPay: Decimal {
        TimeAndPayCalculator.totalPay(totalSeconds: totalSeconds, hourlyRate: employee.hourlyRate)
    }

    private var headerCard: some View {
        GradientCard {
            VStack(alignment: .leading, spacing: LocalTimeClockConstants.spacingS) {
                Text(employee.name)
                    .font(.title3.bold())
                if let role = employee.roleOrTitle {
                    Text(role).foregroundStyle(.secondary)
                }
                StatusBadgeView(isCheckedIn: employee.openEntry != nil, elapsedText: employee.openEntry.map { TimeAndPayCalculator.human(Date.now.timeIntervalSince($0.checkInAt)) })
                Divider()
                Text("Total Time: \(TimeAndPayCalculator.human(totalSeconds))")
                Text("Total Pay: \(TimeAndPayCalculator.formatCurrency(totalPay))")
                Text("Rate: \(TimeAndPayCalculator.formatCurrency(employee.hourlyRate)) / hr")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var timesheetCard: some View {
        GradientCard {
            VStack(alignment: .leading, spacing: LocalTimeClockConstants.spacingM) {
                HStack {
                    Text("Timesheet")
                        .font(.headline)
                    Spacer()
                    Picker("Range", selection: $selectedRange) {
                        ForEach(QuickRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.menu)
                }

                HStack {
                    Button("Export CSV") {
                        exportPayload = ClipboardAndExport.csvExport(
                            employee: employee,
                            entries: filteredEntries,
                            totalSeconds: totalSeconds,
                            totalPay: totalPay
                        )
                        showingExport = true
                    }
                    .buttonStyle(.bordered)

                    Button("Copy as Text") {
                        ClipboardAndExport.copyToClipboard(
                            ClipboardAndExport.timesheetText(
                                employee: employee,
                                entries: filteredEntries,
                                totalSeconds: totalSeconds,
                                totalPay: totalPay
                            )
                        )
                    }
                    .buttonStyle(.bordered)

                    Button("Clear Timesheet", role: .destructive) {
                        showingClearSheetConfirm = true
                    }
                    .buttonStyle(.bordered)
                }

                if filteredEntries.isEmpty {
                    ContentUnavailableView("No Time Entries", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                } else {
                    ForEach(filteredEntries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("In: \(DateFormatting.friendly(entry.checkInAt))")
                            Text("Out: \(entry.checkOutAt.map { DateFormatting.friendly($0) } ?? "In progress")")
                                .foregroundStyle(.secondary)
                            Text("Duration: \(entry.duration.map { TimeAndPayCalculator.human($0) } ?? "In progress")")
                                .font(.caption.monospacedDigit())
                        }
                        .padding(.vertical, 6)
                        Divider()
                    }
                }
            }
        }
    }

    private func loadEditableFields() {
        editName = employee.name
        editRole = employee.roleOrTitle ?? ""
        editRate = NSDecimalNumber(decimal: employee.hourlyRate).stringValue
        editNotes = employee.notes ?? ""
        editActive = employee.isActive
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
