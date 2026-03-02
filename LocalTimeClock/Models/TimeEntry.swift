import Foundation
import SwiftData

@Model
final class TimeEntry {
    var id: UUID = UUID()
    var ownerUserID: String?
    var employee: Employee?
    var checkInAt: Date = Date.now
    var checkOutAt: Date?
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        ownerUserID: String? = nil,
        employee: Employee? = nil,
        checkInAt: Date = .now,
        checkOutAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.ownerUserID = ownerUserID
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
