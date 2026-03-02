import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    let text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct CSVExport {
    let document: CSVDocument
    let filename: String
}

enum Exporters {
    static func copyTimesheet(employee: Employee, entries: [TimeEntry], totalSeconds: TimeInterval, totalPay: Double) {
        let text = textSummary(employee: employee, entries: entries, totalSeconds: totalSeconds, totalPay: totalPay)
        UIPasteboard.general.string = text
    }

    static func textSummary(employee: Employee, entries: [TimeEntry], totalSeconds: TimeInterval, totalPay: Double) -> String {
        let divider = String(repeating: "=", count: 42)
        let sectionDivider = String(repeating: "-", count: 42)
        var lines: [String] = []
        lines.append(divider)
        lines.append("STORE CHECK-IN TIMESHEET")
        lines.append(divider)
        lines.append("Employee : \(employee.name)")
        if let role = employee.roleOrTitle, !role.isEmpty {
            lines.append("Role     : \(role)")
        }
        lines.append("Rate     : \(Formatters.currency(employee.hourlyRate))/hr")
        lines.append("Entries  : \(entries.count)")
        lines.append("Created  : \(Formatters.readableDateTime(.now))")
        lines.append(sectionDivider)
        lines.append("SUMMARY")
        lines.append("Total Time : \(Formatters.hhmmss(seconds: totalSeconds))")
        lines.append("Total Pay  : \(Formatters.currency(totalPay))")

        if entries.isEmpty {
            lines.append(sectionDivider)
            lines.append("No completed time entries.")
            return lines.joined(separator: "\n")
        }

        for (index, entry) in entries.enumerated() {
            let seconds = entry.durationSeconds ?? 0
            let pay = Formatters.pay(seconds: seconds, hourlyRate: employee.hourlyRate)
            lines.append(sectionDivider)
            lines.append("ENTRY \(index + 1)")
            lines.append("Day      : \(Formatters.day(entry.checkInAt))")
            lines.append("Date     : \(Formatters.readableDate(entry.checkInAt))")
            lines.append("Check In : \(Formatters.readableDateTime(entry.checkInAt))")
            lines.append("Check Out: \(entry.checkOutAt.map(Formatters.readableDateTime) ?? "In progress")")
            lines.append("Duration : \(Formatters.hhmmss(seconds: seconds))")
            lines.append("Pay      : \(Formatters.currency(pay))")
        }

        lines.append(sectionDivider)
        return lines.joined(separator: "\n")
    }

    static func makeCSVExport(employee: Employee, entries: [TimeEntry], totalSeconds: TimeInterval, totalPay: Double) -> CSVExport {
        let filename = "Timesheet_\(safeFilename(employee.name))_\(Formatters.csvStamp.string(from: .now))"
        let text = csvText(employee: employee, entries: entries, totalSeconds: totalSeconds, totalPay: totalPay)
        return CSVExport(document: CSVDocument(text: text), filename: filename)
    }

    private static func csvText(employee: Employee, entries: [TimeEntry], totalSeconds: TimeInterval, totalPay: Double) -> String {
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
        return rows.joined(separator: "\n")
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
