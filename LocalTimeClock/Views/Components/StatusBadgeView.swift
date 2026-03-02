import SwiftUI

struct StatusBadgeView: View {
    let isCheckedIn: Bool
    let elapsedText: String?

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isCheckedIn ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            Text(isCheckedIn ? "Checked In" : "Not Checked In")
                .font(.caption.weight(.semibold))
            if let elapsedText, isCheckedIn {
                Text(elapsedText)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill((isCheckedIn ? Color.green : Color.gray).opacity(0.15))
        )
    }
}
