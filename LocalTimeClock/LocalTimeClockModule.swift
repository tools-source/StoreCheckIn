import SwiftUI
import SwiftData

/// Use in host app scene if model container is not already configured for these models:
/// `.modelContainer(for: [Employee.self, TimeEntry.self])`
public enum LocalTimeClockModule {
    public static var models: [any PersistentModel.Type] {
        [Employee.self, TimeEntry.self]
    }
}
