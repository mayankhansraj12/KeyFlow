import Foundation

struct ActivityRecord: Identifiable, Sendable {
    enum Outcome: Equatable, Sendable {
        case succeeded
        case failed(String)
    }

    let id: UUID
    let timestamp: Date
    let mappingName: String
    let trigger: String
    let action: String
    let outcome: Outcome
    let occurrenceCount: Int

    init(
        id: UUID = UUID(),
        timestamp: Date,
        mappingName: String,
        trigger: String,
        action: String,
        outcome: Outcome,
        occurrenceCount: Int = 1
    ) {
        self.id = id
        self.timestamp = timestamp
        self.mappingName = mappingName
        self.trigger = trigger
        self.action = action
        self.outcome = outcome
        self.occurrenceCount = occurrenceCount
    }
}
