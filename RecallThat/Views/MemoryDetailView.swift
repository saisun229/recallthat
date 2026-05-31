import SwiftUI

struct MemoryDetailView: View {
    let memory: Memory

    var body: some View {
        List {
            Section("Info") {
                LabeledContent("Date", value: memory.createdAt.formatted(date: .long, time: .shortened))
                LabeledContent("Status", value: memory.ocrStatus.label)
                LabeledContent("Original", value: memory.originalExists ? "Available" : "Deleted")
            }

            Section("Extracted Text") {
                if memory.ocrText.isEmpty {
                    Text(placeholderText)
                        .foregroundStyle(.secondary)
                } else {
                    Text(memory.ocrText)
                }
            }
        }
        .navigationTitle(memory.title.isEmpty ? "Memory" : memory.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var placeholderText: String {
        switch memory.ocrStatus {
        case .notStarted: return "Text extraction has not started."
        case .pending:    return "Extracting text…"
        case .complete:   return "No text found in this screenshot."
        case .failed:     return "Text extraction failed."
        }
    }
}
