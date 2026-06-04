import SwiftUI
import UIKit

struct MemoryCardView: View {
    let memory: Memory
    var isSelecting: Bool = false
    var isSelected: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 28, alignment: .center)
                    .padding(.top, 10)
            }

            thumbnail

            VStack(alignment: .leading, spacing: 5) {
                Text(displayTitle)
                    .font(.headline)
                    .lineLimit(1)

                if !memory.ocrText.isEmpty {
                    Text(memory.ocrText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    Text(memory.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Spacer()

                    if memory.sourceType == .screenshot && !memory.originalExists {
                        Label("Original deleted", systemImage: "trash")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .labelStyle(.iconOnly)
                    }

                    OCRStatusBadge(status: memory.ocrStatus)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let identifier = memory.photoAssetIdentifier {
            AssetThumbnailView(identifier: identifier, size: 60)
        } else if let path = memory.localThumbnailPath,
                  let uiImage = UIImage(contentsOfFile: path) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: placeholderIcon)
                        .foregroundStyle(.tertiary)
                )
        }
    }

    private var placeholderIcon: String {
        switch memory.sourceType {
        case .screenshot, .sharedImage: return "photo"
        case .sharedURL:                return "link"
        case .sharedText:               return "text.quote"
        }
    }

    private var displayTitle: String {
        if !memory.title.isEmpty { return memory.title }
        return "Screenshot — \(memory.createdAt.formatted(date: .abbreviated, time: .omitted))"
    }
}

// MARK: - OCR Status Badge

private struct OCRStatusBadge: View {
    let status: OCRStatus

    var body: some View {
        Text(status.label)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var color: Color {
        switch status {
        case .notStarted: return .secondary
        case .pending:    return .orange
        case .complete:   return .green
        case .failed:     return .red
        }
    }
}
