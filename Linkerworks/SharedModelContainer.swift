import Foundation
import SwiftData

enum SharedModelContainer {
    static let appGroupIdentifier = "group.com.jonah.linkerworks"
    static let storeFileName = "Linkerworks.store"

    static let schema = Schema([
        Course.self,
        Assignment.self,
        CalendarEvent.self,
        TaskItem.self,
        Section.self,
        DaySchedule.self,
        CompletionRecord.self,
        DaySnapshot.self,
        DaySnapshotCompletionUnit.self,
        MealEntry.self,
        DailyMacroTarget.self,
        SavedMeal.self,
        WorkoutSession.self,
        WorkoutExercise.self,
        WorkoutSet.self,
        DomainReference.self,
    ])

    static func make() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "LinkerworksShared",
            schema: schema,
            url: try storeURL()
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func storeURL(fileManager: FileManager = .default) throws -> URL {
        guard let groupContainerURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            throw SharedStoreError.appGroupContainerUnavailable(appGroupIdentifier)
        }

        let applicationSupportURL = groupContainerURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
        try fileManager.createDirectory(
            at: applicationSupportURL,
            withIntermediateDirectories: true
        )
        return applicationSupportURL.appendingPathComponent(storeFileName)
    }
}

enum SharedStoreError: LocalizedError {
    case appGroupContainerUnavailable(String)

    var errorDescription: String? {
        switch self {
        case let .appGroupContainerUnavailable(identifier):
            "The App Group container \(identifier) is unavailable. Check signing and entitlements."
        }
    }
}
