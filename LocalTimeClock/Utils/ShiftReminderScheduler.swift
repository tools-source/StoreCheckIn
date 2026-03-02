import Foundation
import UserNotifications

enum ShiftReminderScheduler {
    private static let identifierPrefix = "employee-shift-reminder"

    static func syncReminders(for employees: [Employee], ownerUserID: String?) async {
        guard let ownerUserID, !ownerUserID.isEmpty else {
            await removeAllEmployeeReminders()
            return
        }

        let reminderEmployees = employees.filter(\.isActive).filter(\.hasScheduledShift)
        let expectedIdentifiers = Set(reminderEmployees.map { reminderIdentifier(for: $0, ownerUserID: ownerUserID) })

        await removeOrphanedReminders(for: ownerUserID, keeping: expectedIdentifiers)

        guard !reminderEmployees.isEmpty else { return }
        guard await ensureAuthorization() else { return }

        for employee in reminderEmployees {
            guard let request = makeRequest(for: employee, ownerUserID: ownerUserID) else { continue }
            try? await add(request)
        }
    }

    static func removeAllEmployeeReminders() async {
        let identifiers = await managedPendingIdentifiers()
        guard !identifiers.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private static func removeOrphanedReminders(for ownerUserID: String, keeping identifiersToKeep: Set<String>) async {
        let pendingIdentifiers = await managedPendingIdentifiers().filter { $0.hasPrefix(ownerPrefix(ownerUserID)) }
        let identifiersToRemove = pendingIdentifiers.filter { !identifiersToKeep.contains($0) }
        guard !identifiersToRemove.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        center.removeDeliveredNotifications(withIdentifiers: identifiersToRemove)
    }

    private static func makeRequest(for employee: Employee, ownerUserID: String) -> UNNotificationRequest? {
        guard
            let shiftStartMinutes = employee.shiftStartMinutes,
            let shiftEndMinutes = employee.shiftEndMinutes
        else {
            return nil
        }

        let content = UNMutableNotificationContent()
        content.title = "Check in \(employee.name)"
        content.body = "Shift starts at \(Formatters.time(minutesSinceMidnight: shiftStartMinutes)) and ends at \(Formatters.time(minutesSinceMidnight: shiftEndMinutes))."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: shiftStartMinutes / 60, minute: shiftStartMinutes % 60),
            repeats: true
        )

        return UNNotificationRequest(
            identifier: reminderIdentifier(for: employee, ownerUserID: ownerUserID),
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

    private static func managedPendingIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) })
            }
        }
    }

    private static func reminderIdentifier(for employee: Employee, ownerUserID: String) -> String {
        "\(ownerPrefix(ownerUserID)).\(employee.id.uuidString)"
    }

    private static func ownerPrefix(_ ownerUserID: String) -> String {
        "\(identifierPrefix).\(ownerUserID)"
    }
}
