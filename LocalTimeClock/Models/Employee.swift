import Foundation
import SwiftData

@Model
final class Employee {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var name: String
    var roleOrTitle: String?
    var hourlyRate: Decimal
    var notes: String?
    var isActive: Bool

    @Relationship(deleteRule: .cascade, inverse: \TimeEntry.employee)
    var timeEntries: [TimeEntry]

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        name: String,
        roleOrTitle: String? = nil,
        hourlyRate: Decimal,
        notes: String? = nil,
        isActive: Bool = true,
        timeEntries: [TimeEntry] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.name = name
        self.roleOrTitle = roleOrTitle
        self.hourlyRate = hourlyRate
        self.notes = notes
        self.isActive = isActive
        self.timeEntries = timeEntries
    }

    var sortedEntriesNewestFirst: [TimeEntry] {
        timeEntries.sorted { $0.checkInAt > $1.checkInAt }
    }

    var openEntry: TimeEntry? {
        timeEntries.first(where: { $0.checkOutAt == nil })
    }
}
