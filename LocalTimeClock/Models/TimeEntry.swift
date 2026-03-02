import Foundation
import SwiftData

@Model
final class TimeEntry {
    @Attribute(.unique) var id: UUID
    var checkInAt: Date
    var checkOutAt: Date?
    var createdAt: Date
    var source: String?

    var employee: Employee?

    init(
        id: UUID = UUID(),
        checkInAt: Date = .now,
        checkOutAt: Date? = nil,
        createdAt: Date = .now,
        source: String? = "Manual",
        employee: Employee? = nil
    ) {
        self.id = id
        self.checkInAt = checkInAt
        self.checkOutAt = checkOutAt
        self.createdAt = createdAt
        self.source = source
        self.employee = employee
    }

    var duration: TimeInterval? {
        guard let checkOutAt else { return nil }
        return checkOutAt.timeIntervalSince(checkInAt)
    }
}
