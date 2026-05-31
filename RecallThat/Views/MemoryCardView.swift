import SwiftUI

struct MemoryCardView: View {
    let memory: Memory

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(memory.title.isEmpty ? "Untitled" : memory.title)
                .font(.headline)
                .lineLimit(1)

            if !memory.ocrText.isEmpty {
                Text(memory.ocrText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack {
                Text(memory.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()

                Text(memory.ocrStatus.label)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch memory.ocrStatus {
        case .notStarted: return .secondary
        case .pending:    return .orange
        case .complete:   return .green
        case .failed:     return .red
        }
    }
}
