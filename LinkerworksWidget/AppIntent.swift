import AppIntents
import SwiftData
import WidgetKit

struct CompleteRoutineTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Routine Task"
    static var description = IntentDescription("Marks this routine task complete for the selected routine day.")

    @Parameter(title: "Task ID") var taskID: String
    @Parameter(title: "Routine day") var routineDayKey: String

    init() {}
    init(taskID: String, routineDayKey: String) {
        self.taskID = taskID
        self.routineDayKey = routineDayKey
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: taskID) else { throw CompletionIntentError.invalidTask }
        let selectedDay = RoutineDaySelection.selectedDay()
        guard DaySnapshotService.dayKey(for: selectedDay) == routineDayKey else {
            throw CompletionIntentError.routineDayChanged
        }
        let context = ModelContext(try SharedModelContainer.make())
        try RoutineCompletionCommand.complete(
            taskID: id,
            at: selectedDay,
            in: context
        )
        return .result()
    }
}

enum CompletionIntentError: Error { case invalidTask, routineDayChanged }
