import Foundation
import SwiftData

/// Use in host app scene if model container is not already configured for these models:
/// `.modelContainer(for: [Employee.self, TimeEntry.self])`
public enum LocalTimeClockModule {
    private static let storeName = "StoreCheckIn"

    public static var models: [any PersistentModel.Type] {
        [Employee.self, TimeEntry.self]
    }

    public static func makeModelContainer() -> ModelContainer {
        let schema = Schema(models)
        let cloudConfiguration = ModelConfiguration(
            storeName,
            schema: schema,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [cloudConfiguration])
        } catch {
            assertionFailure("Failed to load CloudKit store, falling back to local storage: \(error)")

            do {
                let localConfiguration = ModelConfiguration(
                    storeName,
                    schema: schema,
                    cloudKitDatabase: .none
                )
                return try ModelContainer(for: schema, configurations: [localConfiguration])
            } catch {
                fatalError("Failed to load model container: \(error)")
            }
        }
    }
}
