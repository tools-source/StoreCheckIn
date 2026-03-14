import Foundation

enum Formatters {
    private static let calendar = Calendar.current

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

    static let dayStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    static let timeStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    static let readableDateStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let readableDateTimeStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let readableDateRangeStamp: DateIntervalFormatter = {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
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

    static func day(_ date: Date) -> String {
        dayStamp.string(from: date)
    }

    static func time(_ date: Date) -> String {
        timeStamp.string(from: date)
    }

    static func time(minutesSinceMidnight: Int) -> String {
        time(timeOfDayDate(from: minutesSinceMidnight))
    }

    static func readableDate(_ date: Date) -> String {
        readableDateStamp.string(from: date)
    }

    static func readableDateTime(_ date: Date) -> String {
        readableDateTimeStamp.string(from: date)
    }

    static func readableDateRange(_ interval: DateInterval) -> String {
        let inclusiveEnd = max(interval.start, interval.end.addingTimeInterval(-1))
        return readableDateRangeStamp.string(from: interval.start, to: inclusiveEnd)
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

    static func shift(startMinutes: Int?, endMinutes: Int?) -> String? {
        guard let startMinutes, let endMinutes else { return nil }
        return "\(time(minutesSinceMidnight: startMinutes)) - \(time(minutesSinceMidnight: endMinutes))"
    }

    static func minutesSinceMidnight(for date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    static func timeOfDayDate(from minutesSinceMidnight: Int) -> Date {
        let normalizedMinutes = ((minutesSinceMidnight % 1440) + 1440) % 1440
        let hours = normalizedMinutes / 60
        let minutes = normalizedMinutes % 60
        let components = DateComponents(hour: hours, minute: minutes)
        return calendar.date(from: components) ?? .now
    }
}
