import SwiftUI

struct MemoryCardView: View {
    let memory: Memory

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let identifier = memory.photoAssetIdentifier {
                AssetThumbnailView(identifier: identifier, size: 56)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 56, height: 56)
                    .overlay(Image(systemName: "photo").foregroundStyle(.tertiary))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(memory.title.isEmpty ? "Screenshot" : memory.title)
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
