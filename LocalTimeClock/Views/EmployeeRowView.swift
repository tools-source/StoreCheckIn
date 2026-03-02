import SwiftUI

struct EmployeeRowView: View {
    let employee: Employee
    let onCheckIn: () -> Void
    let onCheckOut: () -> Void

    var body: some View {
        GradientCard {
            VStack(alignment: .leading, spacing: LocalTimeClockConstants.spacingS) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(employee.name)
                            .font(.headline)
                        Text(TimeAndPayCalculator.formatCurrency(employee.hourlyRate) + " / hr")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadgeView(isCheckedIn: employee.openEntry != nil, elapsedText: elapsedText)
                }

                HStack(spacing: LocalTimeClockConstants.spacingS) {
                    Button {
                        onCheckIn()
                    } label: {
                        Label("Check In", systemImage: "clock.badge.checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(employee.openEntry != nil)

                    Button {
                        onCheckOut()
                    } label: {
                        Label("Check Out", systemImage: "clock.badge.xmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(employee.openEntry == nil)
                }
            }
        }
    }

    private var elapsedText: String? {
        guard let inAt = employee.openEntry?.checkInAt else { return nil }
        return TimeAndPayCalculator.human(Date.now.timeIntervalSince(inAt))
    }
}
