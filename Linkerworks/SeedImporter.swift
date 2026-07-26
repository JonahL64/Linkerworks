import Foundation
import SwiftData

enum SeedImporter {
    static let importVersion = 1
    static let importVersionKey = "seedImportVersion"

    private static let weekdays = [
        "Sunday",
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
    ]

    @discardableResult
    static func importIfNeeded(
        into context: ModelContext,
        bundle: Bundle = .main,
        defaults: UserDefaults? = UserDefaults(
            suiteName: SharedModelContainer.appGroupIdentifier
        )
    ) throws -> SeedImportReport {
        guard let defaults else {
            throw SeedImportError.appGroupDefaultsUnavailable
        }

        guard defaults.integer(forKey: importVersionKey) < importVersion else {
            return .skipped
        }

        let scheduleData = try bundledData(named: "schedule", bundle: bundle)
        let referenceData = try bundledData(named: "reference", bundle: bundle)
        let decodedSchedule = try JSONDecoder().decode(
            [String: SeedDay].self,
            from: scheduleData
        )

        var topLevelTaskCount = 0
        var substepCount = 0
        var countsByDay: [String: Int] = [:]

        for (weekdayIndex, weekdayName) in weekdays.enumerated() {
            guard let seedDay = decodedSchedule[weekdayName] else {
                throw SeedImportError.missingDay(weekdayName)
            }

            let daySchedule = DaySchedule(
                weekdayName: weekdayName,
                weekdayIndex: weekdayIndex,
                goalkeepingFocus: seedDay.goalkeepingFocus,
                liftPlan: seedDay.liftPlan,
                targetCalories: seedDay.target.calories,
                targetProteinGrams: seedDay.target.proteinGrams,
                targetFatGrams: seedDay.target.fatGrams,
                targetCarbohydrateGrams: seedDay.target.carbohydrateGrams,
                targetFiberGrams: seedDay.target.fiberGrams
            )

            var dayTaskCount = 0

            for (sectionIndex, seedSection) in seedDay.sections.enumerated() {
                let section = Section(
                    name: seedSection.name,
                    sortOrder: sectionIndex
                )
                daySchedule.sections.append(section)

                var currentParent: TaskItem?
                var childSortOrder = 0

                for (taskIndex, seedTask) in seedSection.tasks.enumerated() {
                    if seedTask.isSubstep {
                        guard let currentParent else {
                            throw SeedImportError.orphanSubstep(
                                day: weekdayName,
                                section: seedSection.name,
                                title: seedTask.title
                            )
                        }

                        let child = TaskItem(
                            title: seedTask.title.trimmingCharacters(in: .whitespaces),
                            time: seedTask.time,
                            detail: seedTask.detail,
                            daysOfWeek: [weekdayName],
                            sortOrder: childSortOrder,
                            domain: .lifting,
                            isSubstep: true
                        )
                        currentParent.children.append(child)
                        childSortOrder += 1
                        substepCount += 1
                        continue
                    }

                    let task = TaskItem(
                        title: seedTask.title,
                        time: seedTask.time,
                        detail: seedTask.detail,
                        daysOfWeek: [weekdayName],
                        sortOrder: taskIndex,
                        domain: try domain(for: seedTask),
                        isSubstep: false
                    )
                    section.tasks.append(task)
                    currentParent = task
                    childSortOrder = 0
                    topLevelTaskCount += 1
                    dayTaskCount += 1
                }
            }

            countsByDay[weekdayName] = dayTaskCount
            context.insert(daySchedule)
        }

        let referenceCount = try importReferences(from: referenceData, into: context)
        try context.save()
        defaults.set(importVersion, forKey: importVersionKey)

        return SeedImportReport(
            didImport: true,
            topLevelTaskCount: topLevelTaskCount,
            substepCount: substepCount,
            referenceCount: referenceCount,
            taskCountsByDay: countsByDay
        )
    }

    private static func bundledData(named name: String, bundle: Bundle) throws -> Data {
        let resourceURL = bundle.url(
            forResource: name,
            withExtension: "json",
            subdirectory: "data"
        ) ?? bundle.url(forResource: name, withExtension: "json")

        guard let resourceURL else {
            throw SeedImportError.missingResource("data/\(name).json")
        }
        return try Data(contentsOf: resourceURL)
    }

    private static func importReferences(
        from data: Data,
        into context: ModelContext
    ) throws -> Int {
        guard let referenceObject = try JSONSerialization.jsonObject(with: data)
            as? [String: Any] else {
            throw SeedImportError.invalidReferenceRoot
        }

        for sourceName in referenceObject.keys.sorted() {
            guard
                let rows = referenceObject[sourceName],
                JSONSerialization.isValidJSONObject(rows),
                let domain = referenceDomain(for: sourceName)
            else {
                throw SeedImportError.invalidReferenceSection(sourceName)
            }

            let rowsJSON = try JSONSerialization.data(
                withJSONObject: rows,
                options: [.sortedKeys]
            )
            context.insert(
                DomainReference(
                    sourceName: sourceName,
                    domain: domain,
                    rowsJSON: rowsJSON
                )
            )
        }

        return referenceObject.count
    }

    private static func domain(for task: SeedTask) throws -> Domain {
        if task.isSubstep { return .lifting }

        let title = task.title.lowercased()

        if title.contains("gk ") { return .goalkeeping }
        if title.contains("posture") || title.contains("wall stand") { return .posture }
        if ["breakfast", "feed", "lunch", "dinner", "totals", "weigh in"]
            .contains(where: title.contains) {
            return .eating
        }
        if ["lift", "rowing", "rest - no lifting"]
            .contains(where: title.contains) {
            return .lifting
        }
        if [
            "brush", "skincare", "spf lip", "whitening", "strips out",
            "grooming", "shave", "shower",
        ].contains(where: title.contains) {
            return .grooming
        }
        if ["wake", "screens down", "lights out"]
            .contains(where: title.contains) {
            return .sleep
        }

        throw SeedImportError.unclassifiedTask(task.title)
    }

    private static func referenceDomain(for sourceName: String) -> Domain? {
        switch sourceName {
        case "Sleep": .sleep
        case "Eating": .eating
        case "Goalkeeping": .goalkeeping
        case "Working Out", "Running": .lifting
        case "Posture": .posture
        case "Brushing", "Skincare", "Shaving", "Small grooming": .grooming
        default: nil
        }
    }
}

struct SeedImportReport: Equatable {
    let didImport: Bool
    let topLevelTaskCount: Int
    let substepCount: Int
    let referenceCount: Int
    let taskCountsByDay: [String: Int]

    static let skipped = SeedImportReport(
        didImport: false,
        topLevelTaskCount: 0,
        substepCount: 0,
        referenceCount: 0,
        taskCountsByDay: [:]
    )
}

private struct SeedDay: Decodable {
    let goalkeepingFocus: String
    let liftPlan: String
    let target: SeedTarget
    let sections: [SeedSection]

    enum CodingKeys: String, CodingKey {
        case goalkeepingFocus = "gk_focus"
        case liftPlan = "lift"
        case target
        case sections
    }
}

private struct SeedTarget: Decodable {
    let calories: Int
    let proteinGrams: Int
    let fatGrams: Int
    let carbohydrateGrams: Int
    let fiberGrams: Int

    enum CodingKeys: String, CodingKey {
        case calories = "kcal"
        case proteinGrams = "protein_g"
        case fatGrams = "fat_g"
        case carbohydrateGrams = "carbs_g"
        case fiberGrams = "fiber_g"
    }
}

private struct SeedSection: Decodable {
    let name: String
    let tasks: [SeedTask]
}

private struct SeedTask: Decodable {
    let time: String?
    let title: String
    let detail: String
    let isSubstep: Bool

    enum CodingKeys: String, CodingKey {
        case time
        case title = "task"
        case detail
        case isSubstep = "is_substep"
    }
}

enum SeedImportError: LocalizedError {
    case appGroupDefaultsUnavailable
    case missingResource(String)
    case missingDay(String)
    case orphanSubstep(day: String, section: String, title: String)
    case unclassifiedTask(String)
    case invalidReferenceRoot
    case invalidReferenceSection(String)

    var errorDescription: String? {
        switch self {
        case .appGroupDefaultsUnavailable:
            "Shared App Group UserDefaults is unavailable."
        case let .missingResource(path):
            "Missing bundled seed resource: \(path)."
        case let .missingDay(day):
            "The schedule seed is missing \(day)."
        case let .orphanSubstep(day, section, title):
            "Sub-step \(title) has no parent in \(day) / \(section)."
        case let .unclassifiedTask(title):
            "No tracker domain matched task: \(title)."
        case .invalidReferenceRoot:
            "reference.json does not contain a top-level object."
        case let .invalidReferenceSection(name):
            "Reference section \(name) is invalid or has no domain mapping."
        }
    }
}
