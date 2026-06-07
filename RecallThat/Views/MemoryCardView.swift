import SwiftUI
import UIKit

struct MemoryCardView: View {
    let memory: Memory
    var isSelecting: Bool = false
    var isSelected: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 28, alignment: .center)
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
            }

            thumbnailView

            // Title + date — no multiline OCR text here to keep rows slim
            VStack(alignment: .leading, spacing: 3) {
                Text(displayTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(memory.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            // Status indicators — center-aligned with the row so they sit
            // at the same height as the NavigationLink chevron
            HStack(spacing: 6) {
                if memory.sourceType == .screenshot && !memory.originalExists {
                    Image(systemName: "photo.badge.checkmark")
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                sourceTypeBadge
                OCRStatusDot(status: memory.ocrStatus)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private var thumbnailView: some View {
        if let identifier = memory.photoAssetIdentifier {
            AssetThumbnailView(identifier: identifier, size: 50)
        } else if let path = memory.localThumbnailPath,
                  let uiImage = UIImage(contentsOfFile: path) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: placeholderIcon)
                        .font(.body)
                        .foregroundStyle(.tertiary)
                )
        }
    }

    @ViewBuilder
    private var sourceTypeBadge: some View {
        switch memory.sourceType {
        case .screenshot, .sharedImage: EmptyView()
        case .sharedURL:
            let src = URLSourceType.detect(from: memory.sourceURL)
            SourceBadge(systemImage: src.systemIcon, color: src.accentColor)
        case .sharedText:  SourceBadge(systemImage: "text.quote",       color: .purple)
        case .sharedPDF:   SourceBadge(systemImage: "doc.fill",         color: .red)
        case .sharedVideo: SourceBadge(systemImage: "play.fill",        color: .indigo)
        case .sharedAudio: SourceBadge(systemImage: "waveform",         color: .teal)
        case .sharedFile:  SourceBadge(systemImage: "doc.badge.plus",   color: .orange)
        }
    }

    private var placeholderIcon: String {
        switch memory.sourceType {
        case .screenshot, .sharedImage: return "photo"
        case .sharedURL:                return URLSourceType.detect(from: memory.sourceURL).systemIcon
        case .sharedText:               return "text.quote"
        case .sharedPDF:                return "doc.richtext"
        case .sharedVideo:              return "video"
        case .sharedAudio:              return "waveform"
        case .sharedFile:               return "doc.badge.plus"
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
            Circle().fill(Color.green).frame(width: 8, height: 8)
        case .pending:
            Circle().fill(Color.orange).frame(width: 8, height: 8)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.red)
        case .notStarted:
            Circle().fill(Color.secondary.opacity(0.3)).frame(width: 8, height: 8)
        }
    }
}
