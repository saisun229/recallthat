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
                    .padding(.top, 8)
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
            }

            thumbnailView

            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                if !memory.ocrText.isEmpty {
                    Text(memory.ocrText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 6)

                HStack(alignment: .center, spacing: 4) {
                    Text(memory.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Spacer()

                    if memory.sourceType == .screenshot && !memory.originalExists {
                        Image(systemName: "photo.badge.checkmark")
                            .font(.caption2)
                            .foregroundStyle(.secondary.opacity(0.5))
                    }

                    OCRStatusDot(status: memory.ocrStatus)
                        .padding(.trailing, 2)
                }
            }
            .padding(.vertical, 2)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private var thumbnailView: some View {
        ZStack(alignment: .bottomTrailing) {
            thumbnailImage
            sourceTypeBadge
                .offset(x: 4, y: 4)
        }
    }

    @ViewBuilder
    private var thumbnailImage: some View {
        if let identifier = memory.photoAssetIdentifier {
            AssetThumbnailView(identifier: identifier, size: 64)
        } else if let path = memory.localThumbnailPath,
                  let uiImage = UIImage(contentsOfFile: path) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.1))
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: placeholderIcon)
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                )
        }
    }

    @ViewBuilder
    private var sourceTypeBadge: some View {
        switch memory.sourceType {
        case .screenshot, .sharedImage:
            EmptyView()
        case .sharedURL:
            SourceBadge(systemImage: "link", color: .blue)
        case .sharedText:
            SourceBadge(systemImage: "text.quote", color: .purple)
        case .sharedPDF:
            SourceBadge(systemImage: "doc.fill", color: .red)
        case .sharedVideo:
            SourceBadge(systemImage: "play.fill", color: .indigo)
        case .sharedAudio:
            SourceBadge(systemImage: "waveform", color: .teal)
        }
    }

    private var placeholderIcon: String {
        switch memory.sourceType {
        case .screenshot, .sharedImage: return "photo"
        case .sharedURL:                return "link"
        case .sharedText:               return "text.quote"
        case .sharedPDF:                return "doc.richtext"
        case .sharedVideo:              return "video"
        case .sharedAudio:              return "waveform"
        }
    }

    private var displayTitle: String {
        if !memory.title.isEmpty { return memory.title }
        return "Screenshot — \(memory.createdAt.formatted(date: .abbreviated, time: .omitted))"
    }
}

// MARK: - Source Badge

private struct SourceBadge: View {
    let systemImage: String
    let color: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .padding(4)
            .background(color, in: Circle())
    }
}

// MARK: - OCR Status Dot

private struct OCRStatusDot: View {
    let status: OCRStatus

    var body: some View {
        switch status {
        case .complete:
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
        case .pending:
            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.red)
        case .notStarted:
            Circle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 8, height: 8)
        }
    }
}
