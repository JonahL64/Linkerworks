import AppIntents
import SwiftData
import WidgetKit

struct CompleteRoutineTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Routine Task"
    static var description = IntentDescription("Marks this routine task complete for today.")

    @Parameter(title: "Task ID") var taskID: String

    init() {}
    init(taskID: String) { self.taskID = taskID }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: taskID) else { throw CompletionIntentError.invalidTask }
        let context = ModelContext(try SharedModelContainer.make())
        try RoutineCompletionCommand.complete(taskID: id, in: context)
        return .result()
    }
}

enum CompletionIntentError: Error { case invalidTask }
