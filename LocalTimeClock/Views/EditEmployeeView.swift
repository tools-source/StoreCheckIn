import SwiftUI

struct EditEmployeeView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var role: String
    @State private var hourlyRate: String
    @State private var hasShiftSchedule: Bool
    @State private var shiftStart: Date
    @State private var shiftEnd: Date
    @State private var notes: String
    @State private var isActive: Bool

    let title: String
    let onSave: (String, String?, Double, Int?, Int?, String?, Bool) -> Void

    init(employee: Employee? = nil, title: String, onSave: @escaping (String, String?, Double, Int?, Int?, String?, Bool) -> Void) {
        self.title = title
        self.onSave = onSave
        _name = State(initialValue: employee?.name ?? "")
        _role = State(initialValue: employee?.roleOrTitle ?? "")
        _hourlyRate = State(initialValue: employee.map { String(format: "%.2f", $0.hourlyRate) } ?? "")
        _hasShiftSchedule = State(initialValue: employee?.hasScheduledShift ?? false)
        _shiftStart = State(initialValue: employee.flatMap { $0.shiftStartMinutes.map(Formatters.timeOfDayDate(from:)) } ?? Self.defaultShiftStart)
        _shiftEnd = State(initialValue: employee.flatMap { $0.shiftEndMinutes.map(Formatters.timeOfDayDate(from:)) } ?? Self.defaultShiftEnd)
        _notes = State(initialValue: employee?.notes ?? "")
        _isActive = State(initialValue: employee?.isActive ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Employee") {
                    TextField("Name", text: $name)
                    TextField("Role / Title (optional)", text: $role)
                    TextField("Hourly Rate", text: $hourlyRate)
                        .keyboardType(.decimalPad)
                    Toggle("Active", isOn: $isActive)
                }

                Section("Shift") {
                    Toggle("Enable Shift Reminders", isOn: $hasShiftSchedule)

                    if hasShiftSchedule {
                        DatePicker("Shift Starts", selection: $shiftStart, displayedComponents: .hourAndMinute)
                        DatePicker("Shift Ends", selection: $shiftEnd, displayedComponents: .hourAndMinute)

                        Text("Daily local notifications will remind you to check in this employee at shift start and check them out at shift end.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let cleanRate = Double(hourlyRate) ?? 0
                        let shiftStartMinutes = hasShiftSchedule ? Formatters.minutesSinceMidnight(for: shiftStart) : nil
                        let shiftEndMinutes = hasShiftSchedule ? Formatters.minutesSinceMidnight(for: shiftEnd) : nil
                        onSave(cleanName, role.nilIfBlank, cleanRate, shiftStartMinutes, shiftEndMinutes, notes.nilIfBlank, isActive)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (Double(hourlyRate) ?? 0) <= 0)
                }
            }
        }
    }

    private static var defaultShiftStart: Date {
        Formatters.timeOfDayDate(from: 9 * 60)
    }

    private static var defaultShiftEnd: Date {
        Formatters.timeOfDayDate(from: 17 * 60)
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
