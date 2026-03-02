import Foundation
import SwiftData

@Model
final class Employee {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var name: String
    var roleOrTitle: String?
    var hourlyRate: Double
    var notes: String?
    var isActive: Bool

    @Relationship(deleteRule: .cascade, inverse: \TimeEntry.employee)
    var entries: [TimeEntry]

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        name: String,
        roleOrTitle: String? = nil,
        hourlyRate: Double,
        notes: String? = nil,
        isActive: Bool = true,
        entries: [TimeEntry] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.name = name
        self.roleOrTitle = roleOrTitle
        self.hourlyRate = hourlyRate
        self.notes = notes
        self.isActive = isActive
        self.entries = entries
    }

    var openEntry: TimeEntry? {
        entries.first(where: { $0.checkOutAt == nil })
    }

    var sortedEntriesNewestFirst: [TimeEntry] {
        entries.sorted { $0.checkInAt > $1.checkInAt }
    }
}
