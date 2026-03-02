import Foundation
import SwiftUI
import UIKit

struct ExportPayload {
    let filename: String
    let data: Data
    let uti: String
}

enum ClipboardAndExport {
    static func timesheetText(employee: Employee, entries: [TimeEntry], totalSeconds: TimeInterval, totalPay: Decimal) -> String {
        let lines = entries.map { entry in
            let inText = DateFormatting.full(entry.checkInAt)
            let outText = entry.checkOutAt.map { DateFormatting.full($0) } ?? "In progress"
            let durationText = entry.duration.map { TimeAndPayCalculator.human($0) } ?? "In progress"
            return "- In: \(inText) | Out: \(outText) | Duration: \(durationText)"
        }

        return """
        Employee: \(employee.name)
        Hourly Rate: \(TimeAndPayCalculator.formatCurrency(employee.hourlyRate))

        Entries:
        \(lines.joined(separator: "\n"))

        Total Time: \(TimeAndPayCalculator.human(totalSeconds))
        Total Pay: \(TimeAndPayCalculator.formatCurrency(totalPay))
        """
    }

    static func csvExport(employee: Employee, entries: [TimeEntry], totalSeconds: TimeInterval, totalPay: Decimal) -> ExportPayload {
        var rows = ["Employee,Hourly Rate,Check In,Check Out,Duration"]
        rows += entries.map { entry in
            let checkIn = DateFormatting.full(entry.checkInAt)
            let checkOut = entry.checkOutAt.map { DateFormatting.full($0) } ?? "In progress"
            let duration = entry.duration.map { TimeAndPayCalculator.human($0) } ?? "In progress"
            return "\(employee.name),\(employee.hourlyRate),\(checkIn),\(checkOut),\(duration)"
        }
        rows.append("Totals,,,\(TimeAndPayCalculator.human(totalSeconds)),\(TimeAndPayCalculator.formatCurrency(totalPay))")

        let csv = rows.joined(separator: "\n")
        return ExportPayload(
            filename: "\(employee.name.replacingOccurrences(of: " ", with: "_"))_timesheet.csv",
            data: Data(csv.utf8),
            uti: "public.comma-separated-values-text"
        )
    }

    static func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
