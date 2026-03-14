import Foundation
import UserNotifications

enum ShiftReminderScheduler {
    private static let identifierPrefix = "employee-shift-reminder"
    private enum ReminderKind: String, CaseIterable {
        case checkIn = "check-in"
        case checkOut = "check-out"
    }

    static func syncReminders(for employees: [Employee], ownerUserID: String?) async {
        guard let ownerUserID, !ownerUserID.isEmpty else {
            await removeAllEmployeeReminders()
            return
        }

        let reminderEmployees = employees.filter(\.isActive).filter(\.hasScheduledShift)
        let expectedIdentifiers = Set(
            reminderEmployees.flatMap { reminderIdentifiers(for: $0, ownerUserID: ownerUserID) }
        )

        await removeOrphanedReminders(for: ownerUserID, keeping: expectedIdentifiers)

        guard !reminderEmployees.isEmpty else { return }
        guard await ensureAuthorization() else { return }

        for employee in reminderEmployees {
            for request in makeRequests(for: employee, ownerUserID: ownerUserID) {
                try? await add(request)
            }
        }
    }

    static func removeAllEmployeeReminders() async {
        let identifiers = await managedNotificationIdentifiers()
        guard !identifiers.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private static func removeOrphanedReminders(for ownerUserID: String, keeping identifiersToKeep: Set<String>) async {
        let managedIdentifiers = await managedNotificationIdentifiers().filter { $0.hasPrefix(ownerPrefix(ownerUserID)) }
        let identifiersToRemove = managedIdentifiers.filter { !identifiersToKeep.contains($0) }
        guard !identifiersToRemove.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        center.removeDeliveredNotifications(withIdentifiers: identifiersToRemove)
    }

    private static func makeRequests(for employee: Employee, ownerUserID: String) -> [UNNotificationRequest] {
        guard
            let shiftStartMinutes = employee.shiftStartMinutes,
            let shiftEndMinutes = employee.shiftEndMinutes
        else {
            return []
        }

        let checkInRequest = makeRequest(
            kind: .checkIn,
            employee: employee,
            ownerUserID: ownerUserID,
            reminderMinutes: shiftStartMinutes,
            title: "Check in \(employee.name)",
            body: "Shift starts at \(Formatters.time(minutesSinceMidnight: shiftStartMinutes)). Don't forget to check in \(employee.name)."
        )
        let checkOutRequest = makeRequest(
            kind: .checkOut,
            employee: employee,
            ownerUserID: ownerUserID,
            reminderMinutes: shiftEndMinutes,
            title: "Check out \(employee.name)",
            body: "Shift ends at \(Formatters.time(minutesSinceMidnight: shiftEndMinutes)). Don't forget to check out \(employee.name)."
        )

        return [checkInRequest, checkOutRequest]
    }

    private static func makeRequest(
        kind: ReminderKind,
        employee: Employee,
        ownerUserID: String,
        reminderMinutes: Int,
        title: String,
        body: String
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: reminderMinutes / 60, minute: reminderMinutes % 60),
            repeats: true
        )

        return UNNotificationRequest(
            identifier: reminderIdentifier(for: employee, kind: kind, ownerUserID: ownerUserID),
            content: content,
            trigger: trigger
        )
    }

    private static func ensureAuthorization() async -> Bool {
        let settings = await notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private static func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private static func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private static func managedNotificationIdentifiers() async -> [String] {
        let pendingIdentifiers = await pendingManagedIdentifiers()
        let deliveredIdentifiers = await deliveredManagedIdentifiers()
        return Array(Set(pendingIdentifiers + deliveredIdentifiers))
    }

    private static func pendingManagedIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) })
            }
        }
    }

    private static func deliveredManagedIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
                continuation.resume(returning: notifications.map(\.request.identifier).filter { $0.hasPrefix(identifierPrefix) })
            }
        }
    }

    private static func reminderIdentifiers(for employee: Employee, ownerUserID: String) -> [String] {
        ReminderKind.allCases.map { reminderIdentifier(for: employee, kind: $0, ownerUserID: ownerUserID) }
    }

    private static func reminderIdentifier(for employee: Employee, kind: ReminderKind, ownerUserID: String) -> String {
        "\(ownerPrefix(ownerUserID)).\(employee.id.uuidString).\(kind.rawValue)"
    }

    private static func ownerPrefix(_ ownerUserID: String) -> String {
        "\(identifierPrefix).\(ownerUserID)"
    }
}
