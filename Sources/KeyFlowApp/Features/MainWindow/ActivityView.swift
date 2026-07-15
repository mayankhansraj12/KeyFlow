import AppKit
import KeyFlowCore
import SwiftUI

struct ActivityView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Live Activity").font(.title2.weight(.semibold))
                    Text("The latest 100 executions are kept in memory and are not written to disk.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Clear", action: { model.clearActivity() }).disabled(model.activities.isEmpty)
            }
            .padding()
            Divider()
            if model.activities.isEmpty {
                ContentUnavailableView(
                    "No Activity Yet",
                    systemImage: "waveform.path.ecg",
                    description: Text("Trigger or test a mapping to see its result here.")
                )
            } else {
                List(model.activities) { activity in
                    HStack(alignment: .top, spacing: 12) {
                        outcomeIcon(activity.outcome)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(activity.mappingName).fontWeight(.medium)
                                if activity.occurrenceCount > 1 {
                                    Text("×\(activity.occurrenceCount)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text("\(activity.trigger) → \(activity.action)")
                                .font(.caption).foregroundStyle(.secondary)
                            if case let .failed(message) = activity.outcome {
                                Text(message).font(.caption).foregroundStyle(.red)
                            }
                        }
                        Spacer()
                        Text(activity.timestamp, style: .time)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private func outcomeIcon(_ outcome: ActivityRecord.Outcome) -> some View {
        switch outcome {
        case .succeeded:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }
}
