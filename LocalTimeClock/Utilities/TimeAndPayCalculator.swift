import Foundation

enum TimeAndPayCalculator {
    static func totalWorkedSeconds(entries: [TimeEntry], in range: DateInterval? = nil) -> TimeInterval {
        entries
            .compactMap { entry -> TimeInterval? in
                guard let out = entry.checkOutAt else { return nil }
                if let range {
                    guard range.contains(entry.checkInAt) || range.contains(out) else { return nil }
                }
                return out.timeIntervalSince(entry.checkInAt)
            }
            .reduce(0, +)
    }

    static func totalPay(totalSeconds: TimeInterval, hourlyRate: Decimal) -> Decimal {
        guard totalSeconds > 0 else { return 0 }
        let hours = Decimal(totalSeconds) / 3600
        return hours * hourlyRate
    }

    static func hms(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }

    static func human(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return "\(hours)h \(minutes)m \(String(format: "%02d", secs))s"
    }

    static func formatCurrency(_ amount: Decimal, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }

    // Lightweight helper checks (unit-test-like).
    static func selfCheck() -> [String] {
        var output: [String] = []
        let demoDuration = TimeInterval(3_729)
        output.append(hms(demoDuration) == "01:02:09" ? "hms ok" : "hms fail")
        output.append(human(demoDuration) == "1h 2m 09s" ? "human ok" : "human fail")
        let pay = totalPay(totalSeconds: 7_200, hourlyRate: 20)
        output.append(pay == 40 ? "pay ok" : "pay fail")
        return output
    }
}
