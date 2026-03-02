import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum Exporters {
    static func copyTimesheet(employee: Employee, entries: [TimeEntry], totalSeconds: TimeInterval, totalPay: Double) {
        let text = textSummary(employee: employee, entries: entries, totalSeconds: totalSeconds, totalPay: totalPay)
        UIPasteboard.general.string = text
    }

    static func textSummary(employee: Employee, entries: [TimeEntry], totalSeconds: TimeInterval, totalPay: Double) -> String {
        var lines: [String] = []
        lines.append("Employee: \(employee.name)")
        lines.append("Rate: \(Formatters.currency(employee.hourlyRate))/hr")
        lines.append("Entries: \(entries.count)")
        lines.append("")

        for entry in entries {
            let checkIn = Formatters.dateTime(entry.checkInAt)
            let checkOut = entry.checkOutAt.map(Formatters.dateTime) ?? "In progress"
            let seconds = entry.durationSeconds ?? 0
            let pay = Formatters.pay(seconds: seconds, hourlyRate: employee.hourlyRate)
            lines.append("In: \(checkIn) | Out: \(checkOut) | Duration: \(Formatters.hhmmss(seconds: seconds)) | Pay: \(Formatters.currency(pay))")
        }

        lines.append("")
        lines.append("Totals")
        lines.append("TotalSeconds: \(Int(totalSeconds))")
        lines.append("TotalHHMMSS: \(Formatters.hhmmss(seconds: totalSeconds))")
        lines.append("TotalPay: \(Formatters.currency(totalPay))")
        return lines.joined(separator: "\n")
    }

    static func makeCSV(employee: Employee, entries: [TimeEntry], totalSeconds: TimeInterval, totalPay: Double) throws -> URL {
        var rows: [String] = [
            "Employee,HourlyRate,CheckIn,CheckOut,DurationSeconds,DurationHHMMSS,PayForEntry"
        ]

        for entry in entries {
            let seconds = entry.durationSeconds ?? 0
            let pay = Formatters.pay(seconds: seconds, hourlyRate: employee.hourlyRate)
            let checkIn = Formatters.dateTime(entry.checkInAt)
            let checkOut = entry.checkOutAt.map(Formatters.dateTime) ?? "In progress"
            rows.append([
                csvEscape(employee.name),
                String(format: "%.2f", employee.hourlyRate),
                csvEscape(checkIn),
                csvEscape(checkOut),
                String(Int(seconds)),
                csvEscape(Formatters.hhmmss(seconds: seconds)),
                String(format: "%.2f", pay)
            ].joined(separator: ","))
        }

        rows.append("")
        rows.append("TotalSeconds,TotalHHMMSS,TotalPay")
        rows.append("\(Int(totalSeconds)),\(Formatters.hhmmss(seconds: totalSeconds)),\(String(format: "%.2f", totalPay))")

        let filename = "Timesheet_\(safeFilename(employee.name))_\(Formatters.csvStamp.string(from: .now)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try rows.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func csvEscape(_ text: String) -> String {
        let escaped = text.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static func safeFilename(_ text: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let mapped = text.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        return String(mapped)
    }
}
