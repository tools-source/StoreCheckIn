import Foundation
import SwiftData

@Model
final class Employee {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var name: String = ""
    var roleOrTitle: String?
    var hourlyRate: Double = 0
    var notes: String?
    var isActive: Bool = true

    @Relationship(deleteRule: .cascade, inverse: \TimeEntry.employee)
    var entries: [TimeEntry]?

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

    var entriesList: [TimeEntry] {
        entries ?? []
    }

    var openEntry: TimeEntry? {
        entriesList.first(where: { $0.checkOutAt == nil })
    }

    var sortedEntriesNewestFirst: [TimeEntry] {
        entriesList.sorted { $0.checkInAt > $1.checkInAt }
    }
}
