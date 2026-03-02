import UIKit

enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
