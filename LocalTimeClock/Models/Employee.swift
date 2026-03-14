import Foundation
import SwiftData

@Model
final class Employee {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var ownerUserID: String?
    var name: String = ""
    var roleOrTitle: String?
    var hourlyRate: Double = 0
    var shiftStartMinutes: Int?
    var shiftEndMinutes: Int?
    var notes: String?
    var isActive: Bool = true
    var isArchived: Bool = false
    var sourceEmployeeID: UUID?

    @Relationship(deleteRule: .cascade, inverse: \TimeEntry.employee)
    var entries: [TimeEntry]?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        ownerUserID: String? = nil,
        name: String,
        roleOrTitle: String? = nil,
        hourlyRate: Double,
        shiftStartMinutes: Int? = nil,
        shiftEndMinutes: Int? = nil,
        notes: String? = nil,
        isActive: Bool = true,
        isArchived: Bool = false,
        sourceEmployeeID: UUID? = nil,
        entries: [TimeEntry] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.ownerUserID = ownerUserID
        self.name = name
        self.roleOrTitle = roleOrTitle
        self.hourlyRate = hourlyRate
        self.shiftStartMinutes = shiftStartMinutes
        self.shiftEndMinutes = shiftEndMinutes
        self.notes = notes
        self.isActive = isActive
        self.isArchived = isArchived
        self.sourceEmployeeID = sourceEmployeeID
        self.entries = entries
    }

    var entriesList: [TimeEntry] {
        entries ?? []
    }

    var openEntry: TimeEntry? {
        entriesList.first(where: { $0.checkOutAt == nil && !$0.isArchived })
    }

    var sortedEntriesNewestFirst: [TimeEntry] {
        entriesList.sorted { $0.checkInAt > $1.checkInAt }
    }

    var hasScheduledShift: Bool {
        shiftStartMinutes != nil && shiftEndMinutes != nil
    }

    var shiftSummary: String? {
        Formatters.shift(startMinutes: shiftStartMinutes, endMinutes: shiftEndMinutes)
    }
}
