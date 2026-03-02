import SwiftUI

struct GradientCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(LocalTimeClockConstants.spacingM)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: LocalTimeClockConstants.cardCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(.secondarySystemBackground), Color(.tertiarySystemBackground)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: .black.opacity(0.06), radius: LocalTimeClockConstants.shadowRadius, x: 0, y: 2)
    }
}
