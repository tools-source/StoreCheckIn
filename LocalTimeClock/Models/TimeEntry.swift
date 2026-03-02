import Foundation
import SwiftData

@Model
final class TimeEntry {
    @Attribute(.unique) var id: UUID
    var employee: Employee?
    var checkInAt: Date
    var checkOutAt: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        employee: Employee? = nil,
        checkInAt: Date = .now,
        checkOutAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.employee = employee
        self.checkInAt = checkInAt
        self.checkOutAt = checkOutAt
        self.createdAt = createdAt
    }

    var durationSeconds: TimeInterval? {
        guard let checkOutAt else { return nil }
        return max(0, checkOutAt.timeIntervalSince(checkInAt))
    }
}
