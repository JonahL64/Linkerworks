import SwiftData
import SwiftUI

@main
struct LinkerworksApp: App {
    private let sharedModelContainer: ModelContainer

    init() {
        do {
            let container = try SharedModelContainer.make()
            let report = try SeedImporter.importIfNeeded(into: container.mainContext)
            let defaults = UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier) ?? .standard
            _ = try RoutineDayPhaseMigration.migrateIfNeeded(
                in: container.mainContext,
                defaults: defaults
            )
            _ = try DaySnapshotService.backfillIfNeeded(
                in: container.mainContext,
                defaults: defaults
            )
            sharedModelContainer = container

#if DEBUG
            let storeURL = try SharedModelContainer.storeURL()
            print("SwiftData store: \(storeURL.path)")
            if report.didImport {
                print(
                    "Seed import complete: \(report.topLevelTaskCount) tasks, "
                    + "\(report.substepCount) nested sub-steps, "
                    + "\(report.referenceCount) reference tables"
                )
                for day in report.taskCountsByDay.keys.sorted() {
                    print("\(day): \(report.taskCountsByDay[day, default: 0]) tasks")
                }
            } else {
                print("Seed import skipped: version \(SeedImporter.importVersion) already imported")
            }
#endif
        } catch {
            fatalError("Unable to initialize Linkerworks data: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
