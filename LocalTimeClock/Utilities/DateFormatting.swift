import Foundation

enum DateFormatting {
    static let fullTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static let friendlyTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    static func full(_ date: Date) -> String {
        fullTimestamp.string(from: date)
    }

    static func friendly(_ date: Date) -> String {
        friendlyTimestamp.string(from: date)
    }
}
