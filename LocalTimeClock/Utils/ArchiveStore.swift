import Foundation
import SwiftData

enum ArchiveStore {
    static func migrateLegacySnapshots(for employees: [Employee], ownerUserID: String?, context: ModelContext) {
        guard let ownerUserID else { return }

        let liveEmployees = employees.filter { $0.ownerUserID == ownerUserID && $0.sourceEmployeeID == nil }
        let liveEmployeesByID = Dictionary(uniqueKeysWithValues: liveEmployees.map { ($0.id, $0) })
        var didChange = false

        for employee in liveEmployees where employee.isArchived {
            employee.isArchived = false
            didChange = true
        }

        for snapshot in employees where snapshot.ownerUserID == ownerUserID && snapshot.sourceEmployeeID != nil {
            guard let sourceEmployeeID = snapshot.sourceEmployeeID, let sourceEmployee = liveEmployeesByID[sourceEmployeeID] else {
                context.delete(snapshot)
                didChange = true
                continue
            }

            for entry in snapshot.entriesList {
                context.insert(
                    TimeEntry(
                        ownerUserID: entry.ownerUserID,
                        employee: sourceEmployee,
                        checkInAt: entry.checkInAt,
                        checkOutAt: entry.checkOutAt,
                        createdAt: entry.createdAt,
                        isArchived: true
                    )
                )
            }

            context.delete(snapshot)
            didChange = true
        }

        if didChange {
            try? context.save()
        }
    }

    static func activeEntries(for employee: Employee) -> [TimeEntry] {
        employee.entriesList
            .filter { !$0.isArchived }
            .sorted { $0.checkInAt > $1.checkInAt }
    }

    static func archivedEntries(for employee: Employee) -> [TimeEntry] {
        employee.entriesList
            .filter { $0.isArchived }
            .sorted { $0.checkInAt > $1.checkInAt }
    }

    static func archivedEntries(for employee: Employee, in interval: DateInterval?) -> [TimeEntry] {
        archivedEntries(for: employee)
            .filter { entry in
                guard let interval else { return true }
                return interval.contains(entry.checkInAt)
            }
    }

    static func hasActiveEntries(for employee: Employee) -> Bool {
        employee.entriesList.contains { !$0.isArchived }
    }

    static func hasArchivedEntries(for employee: Employee) -> Bool {
        employee.entriesList.contains { $0.isArchived }
    }

    static func hasArchivedEntries(for employee: Employee, in interval: DateInterval?) -> Bool {
        !archivedEntries(for: employee, in: interval).isEmpty
    }
}
