import Foundation

enum Formatters {
    static let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static let csvStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()

    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()

    static func dateTime(_ date: Date) -> String {
        timestamp.string(from: date)
    }

    static func hhmmss(seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }

    static func human(seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return "\(hours)h \(minutes)m \(String(format: "%02d", secs))s"
    }

    static func currency(_ amount: Double) -> String {
        currency.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    static func workedSeconds(for entries: [TimeEntry]) -> TimeInterval {
        entries.reduce(into: 0) { partialResult, entry in
            guard let seconds = entry.durationSeconds else { return }
            partialResult += seconds
        }
    }

    static func pay(seconds: TimeInterval, hourlyRate: Double) -> Double {
        (seconds / 3600.0) * hourlyRate
    }
}
