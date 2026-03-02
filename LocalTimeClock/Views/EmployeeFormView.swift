import SwiftUI

struct EmployeeFormView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    @Binding var name: String
    @Binding var role: String
    @Binding var hourlyRate: String
    @Binding var notes: String
    @Binding var isActive: Bool
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Employee") {
                    TextField("Name", text: $name)
                    TextField("Role / Title", text: $role)
                    TextField("Hourly Rate", text: $hourlyRate)
                        .keyboardType(.decimalPad)
                    Toggle("Active", isOn: $isActive)
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Decimal(string: hourlyRate) == nil)
                }
            }
        }
    }
}
