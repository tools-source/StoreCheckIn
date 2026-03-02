import Foundation
import SwiftData

enum QuickRange: String, CaseIterable, Identifiable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case all = "All"

    var id: String { rawValue }

    func dateInterval(from now: Date = .now, calendar: Calendar = .current) -> DateInterval? {
        switch self {
        case .today:
            guard let start = calendar.dateInterval(of: .day, for: now)?.start else { return nil }
            return DateInterval(start: start, end: now)
        case .thisWeek:
            guard let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return nil }
            return DateInterval(start: start, end: now)
        case .thisMonth:
            guard let start = calendar.dateInterval(of: .month, for: now)?.start else { return nil }
            return DateInterval(start: start, end: now)
        case .all:
            return nil
        }
    }
}

@MainActor
final class EmployeeListViewModel: ObservableObject {
    @Published var searchText = ""

    func filteredEmployees(_ employees: [Employee]) -> [Employee] {
        guard !searchText.isEmpty else {
            return employees.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        return employees
            .filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func checkIn(employee: Employee, context: ModelContext, now: Date = .now) {
        guard employee.openEntry == nil else { return }
        let entry = TimeEntry(checkInAt: now, checkOutAt: nil, createdAt: now, source: "Manual", employee: employee)
        context.insert(entry)
        try? context.save()
    }

    func checkOut(employee: Employee, context: ModelContext, now: Date = .now) {
        guard let openEntry = employee.openEntry else { return }
        openEntry.checkOutAt = now
        try? context.save()
    }

    func clearAllData(context: ModelContext, employees: [Employee], entries: [TimeEntry]) {
        entries.forEach(context.delete)
        employees.forEach(context.delete)
        try? context.save()
    }
}
