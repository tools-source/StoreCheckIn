import SwiftUI

struct EditEmployeeView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var role: String
    @State private var hourlyRate: String
    @State private var notes: String
    @State private var isActive: Bool

    let title: String
    let onSave: (String, String?, Double, String?, Bool) -> Void

    init(employee: Employee? = nil, title: String, onSave: @escaping (String, String?, Double, String?, Bool) -> Void) {
        self.title = title
        self.onSave = onSave
        _name = State(initialValue: employee?.name ?? "")
        _role = State(initialValue: employee?.roleOrTitle ?? "")
        _hourlyRate = State(initialValue: employee.map { String(format: "%.2f", $0.hourlyRate) } ?? "")
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
                        onSave(cleanName, role.nilIfBlank, cleanRate, notes.nilIfBlank, isActive)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (Double(hourlyRate) ?? 0) <= 0)
                }
            }
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
