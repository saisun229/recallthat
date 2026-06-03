import SwiftUI

struct MemoryDetailView: View {
    let memory: Memory
    @State private var viewModel: MemoryDetailViewModel
    @Environment(AppEnvironment.self) private var appEnv

    init(memory: Memory) {
        self.memory = memory
        self._viewModel = State(initialValue: MemoryDetailViewModel(memory: memory))
    }

    var body: some View {
        List {
            thumbnailSection
            infoSection
            ocrTextSection
            deleteSection
        }
        .navigationTitle(displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete Original Screenshot?",
            isPresented: $viewModel.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Original Screenshot", role: .destructive) {
                Task {
                    await viewModel.deleteOriginal(
                        photoService: appEnv.photoLibraryService,
                        repository: appEnv.memoryRepository
                    )
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The screenshot will be removed from your Photos library.\n\nWhat stays in RecallThat:\n• Extracted text\n• Title\n• Date\n• Thumbnail\n\nThis cannot be undone.")
        }
        .alert("Delete Failed", isPresented: .init(
            get: { viewModel.deleteError != nil },
            set: { if !$0 { viewModel.deleteError = nil } }
        )) {
            Button("OK") { viewModel.deleteError = nil }
        } message: {
            Text(viewModel.deleteError ?? "")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var thumbnailSection: some View {
        if let identifier = viewModel.memory.photoAssetIdentifier, viewModel.memory.originalExists {
            Section {
                AssetThumbnailView(identifier: identifier, size: 280)
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
    }

    private var infoSection: some View {
        Section("Info") {
            LabeledContent("Date", value: viewModel.memory.createdAt.formatted(date: .long, time: .shortened))
            LabeledContent("Indexed", value: viewModel.memory.importedAt.formatted(date: .abbreviated, time: .omitted))
            LabeledContent("OCR", value: viewModel.memory.ocrStatus.label)
            LabeledContent("Original") {
                if viewModel.memory.originalExists {
                    Label("Available", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("Deleted", systemImage: "trash")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var ocrTextSection: some View {
        Section("Extracted Text") {
            if viewModel.memory.ocrText.isEmpty {
                Text(placeholderText)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                Text(viewModel.memory.ocrText)
                    .font(.body)
                    .textSelection(.enabled)
            }
        }
    }

    @ViewBuilder
    private var deleteSection: some View {
        if viewModel.memory.originalExists {
            Section {
                Button(role: .destructive) {
                    viewModel.showDeleteConfirmation = true
                } label: {
                    if viewModel.isDeleting {
                        HStack {
                            ProgressView()
                            Text("Deleting…")
                        }
                    } else {
                        Label("Delete Original Screenshot", systemImage: "trash")
                    }
                }
                .disabled(viewModel.isDeleting)
            } footer: {
                Text("Removes the screenshot from your Photos library. The extracted text, title, and date stay in RecallThat so you can still search for this memory.")
                    .font(.footnote)
            }
        }
    }

    // MARK: - Helpers

    private var displayTitle: String {
        viewModel.memory.title.isEmpty
            ? "Screenshot — \(viewModel.memory.createdAt.formatted(date: .abbreviated, time: .omitted))"
            : viewModel.memory.title
    }

    private var placeholderText: String {
        switch viewModel.memory.ocrStatus {
        case .notStarted: return "Text extraction has not started yet."
        case .pending:    return "Extracting text…"
        case .complete:   return "No text was found in this screenshot."
        case .failed:     return "Text extraction failed."
        }
    }
}
