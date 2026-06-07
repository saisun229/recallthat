import SwiftUI
import UIKit

struct MemoryDetailView: View {
    let memory: Memory
    @State private var viewModel: MemoryDetailViewModel
    @State private var isTextExpanded = false
    @Environment(AppEnvironment.self) private var appEnv

    init(memory: Memory) {
        self.memory = memory
        self._viewModel = State(initialValue: MemoryDetailViewModel(memory: memory))
    }

    var body: some View {
        List {
            thumbnailSection
            openSourceSection
            infoSection
            ocrTextSection
            deleteSection
        }
        .navigationTitle(displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete Original Photo?",
            isPresented: $viewModel.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete from Photos", role: .destructive) {
                Task {
                    await viewModel.deleteOriginal(
                        photoService: appEnv.photoLibraryService,
                        repository: appEnv.memoryRepository
                    )
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The photo is removed from your Photos library.\n\nWhat stays in RecallThat:\n• Extracted text\n• Title\n• Date\n• Thumbnail\n\nThis cannot be undone.")
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

    // MARK: - Thumbnail section

    @ViewBuilder
    private var thumbnailSection: some View {
        if let identifier = viewModel.memory.photoAssetIdentifier, viewModel.memory.originalExists {
            Section {
                AssetThumbnailView(identifier: identifier, size: 280)
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        } else if let path = viewModel.memory.localThumbnailPath,
                  let uiImage = UIImage(contentsOfFile: path) {
            Section {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
    }

    // MARK: - Open source section (URL memories only)

    @ViewBuilder
    private var openSourceSection: some View {
        if viewModel.memory.sourceType == .sharedURL,
           let urlStr = viewModel.memory.sourceURL,
           let url = URL(string: urlStr) {
            let source = URLSourceType.detect(from: urlStr)
            Section {
                Link(destination: url) {
                    HStack(spacing: 14) {
                        Image(systemName: source.systemIcon)
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(source.accentColor, in: RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(source.openLabel)
                                .fontWeight(.semibold)
                                .foregroundStyle(source.accentColor)
                            Text(hostDisplay(urlStr))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right.square.fill")
                            .foregroundStyle(source.accentColor.opacity(0.6))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func hostDisplay(_ urlStr: String) -> String {
        guard let host = URL(string: urlStr)?.host else { return urlStr }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    // MARK: - Info section

    private var infoSection: some View {
        Section("Details") {
            // Captured
            HStack(alignment: .center) {
                Label("Captured", systemImage: "camera")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.memory.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.trailing)
            }

            // Indexed — green dot sits on the label side for clear alignment
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.secondary)
                    .frame(width: 20, alignment: .center)
                Circle()
                    .fill(indexedDotColor)
                    .frame(width: 8, height: 8)
                Text("Indexed")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.memory.importedAt.formatted(date: .abbreviated, time: .omitted))
                    .foregroundStyle(.primary)
            }

            // Text extraction status
            HStack(alignment: .center) {
                Label("Text", systemImage: "text.page")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.memory.ocrStatus.label)
                    .foregroundStyle(ocrStatusColor)
                    .fontWeight(.medium)
            }

            // Original photo
            HStack(alignment: .center) {
                Label("Original", systemImage: "photo")
                    .foregroundStyle(.secondary)
                Spacer()
                if viewModel.memory.originalExists {
                    Label("In Photos", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("Deleted", systemImage: "photo.badge.xmark")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - OCR text section — collapsible

    private var ocrTextSection: some View {
        Section {
            DisclosureGroup(isExpanded: $isTextExpanded) {
                if viewModel.memory.ocrText.isEmpty {
                    Text(placeholderText)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .padding(.top, 4)
                } else {
                    Text(viewModel.memory.ocrText)
                        .font(.body)
                        .textSelection(.enabled)
                        .padding(.top, 4)
                }
            } label: {
                Label("Extracted Text", systemImage: "text.page.fill")
                    .fontWeight(.medium)
            }
        }
    }

    // MARK: - Delete section

    @ViewBuilder
    private var deleteSection: some View {
        if viewModel.memory.originalExists {
            Section {
                Button {
                    viewModel.showDeleteConfirmation = true
                } label: {
                    if viewModel.isDeleting {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Deleting…")
                                .foregroundStyle(.orange)
                        }
                    } else {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.badge.minus")
                                .font(.title3)
                                .foregroundStyle(.orange)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Delete Original Photo")
                                    .foregroundStyle(.orange)
                                    .fontWeight(.medium)
                                Text("Removes from Photos · Text stays in RecallThat")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .disabled(viewModel.isDeleting)
            } footer: {
                Text("Your extracted text, title, and date remain fully searchable in RecallThat after the photo is deleted.")
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

    private var indexedDotColor: Color {
        viewModel.memory.ocrStatus == .complete ? .green : Color.secondary.opacity(0.35)
    }

    private var ocrStatusColor: Color {
        switch viewModel.memory.ocrStatus {
        case .complete:   return .green
        case .pending:    return .orange
        case .failed:     return .red
        case .notStarted: return .secondary
        }
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
