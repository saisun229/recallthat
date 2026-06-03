import SwiftUI

struct MemoryDetailView: View {
    let memory: Memory

    var body: some View {
        List {
            if let identifier = memory.photoAssetIdentifier, memory.originalExists {
                Section {
                    AssetThumbnailView(identifier: identifier, size: 280)
                        .frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            Section("Info") {
                LabeledContent("Date", value: memory.createdAt.formatted(date: .long, time: .shortened))
                LabeledContent("Indexed", value: memory.importedAt.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("OCR", value: memory.ocrStatus.label)
                LabeledContent("Original") {
                    if memory.originalExists {
                        Label("Available", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Deleted", systemImage: "trash")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Extracted Text") {
                if memory.ocrText.isEmpty {
                    Text(placeholderText)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    Text(memory.ocrText)
                        .font(.body)
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle(displayTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var displayTitle: String {
        memory.title.isEmpty
            ? "Screenshot — \(memory.createdAt.formatted(date: .abbreviated, time: .omitted))"
            : memory.title
    }

    private var placeholderText: String {
        switch memory.ocrStatus {
        case .notStarted: return "Text extraction has not started yet."
        case .pending:    return "Extracting text…"
        case .complete:   return "No text was found in this screenshot."
        case .failed:     return "Text extraction failed. You can retry from the home screen."
        }
    }
}
