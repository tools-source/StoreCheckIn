import SwiftUI

struct EmployeeCardView: View {
    let employee: Employee
    let onCheckIn: () -> Void
    let onCheckOut: () -> Void
    @State private var now: Date = .now

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
                Text("Rate: \(Formatters.currency(employee.hourlyRate))/hr")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let open = employee.openEntry {
                    let elapsed = max(0, now.timeIntervalSince(open.checkInAt))
                    Text("Live: \(Formatters.hhmmss(seconds: elapsed))")
                        .font(.caption.monospacedDigit())
                }
            }

            HStack(spacing: 10) {
                Button("Check In", action: onCheckIn)
                    .buttonStyle(.borderedProminent)
                    .disabled(employee.openEntry != nil || !employee.isActive)

                Button("Check Out", action: onCheckOut)
                    .buttonStyle(.bordered)
                    .disabled(employee.openEntry == nil)
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
        .onReceive(timer) { now = $0 }
    }

    private var statusBadge: some View {
        Text(employee.openEntry == nil ? "Not Checked In" : "Checked In")
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(employee.openEntry == nil ? Color.gray.opacity(0.2) : Color.green.opacity(0.2))
            .foregroundStyle(employee.openEntry == nil ? Color.secondary : Color.green)
            .clipShape(Capsule())
    }
}
