import SwiftUI
@preconcurrency import Photos

struct HomeView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @State private var viewModel = HomeViewModel()
    @State private var safeDeleteTarget: Memory? = nil
    @State private var showBatchSafeDeleteConfirm = false
    @State private var showBatchHardDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.permissionStatus {
                case .authorized, .limited:
                    authorizedContent
                case .denied, .restricted:
                    PhotoPermissionView(status: viewModel.permissionStatus, onRequestAccess: {})
                case .notDetermined:
                    PhotoPermissionView(status: .notDetermined) {
                        Task { await viewModel.requestPhotoAccess(using: appEnv.photoLibraryService) }
                    }
                @unknown default:
                    authorizedContent
                }
            }
            .navigationTitle("RecallThat")
            .toolbar { toolbarContent }
        }
        .task {
            await runFullSync()
        }
        .onChange(of: viewModel.permissionStatus) { _, newStatus in
            guard newStatus == .authorized || newStatus == .limited else { return }
            Task { await runFullSync() }
        }
        .onChange(of: appEnv.memoriesVersion) { _, _ in
            Task { await runFullSync() }
        }
        .refreshable {
            await runFullSync()
        }
        .alert("Delete Original Screenshot?", isPresented: .init(
            get: { safeDeleteTarget != nil },
            set: { if !$0 { safeDeleteTarget = nil } }
        )) {
            Button("Delete from Photos", role: .destructive) {
                guard let target = safeDeleteTarget else { return }
                safeDeleteTarget = nil
                Task {
                    await viewModel.safeDelete(
                        target,
                        photoService: appEnv.photoLibraryService,
                        repository: appEnv.memoryRepository
                    )
                }
            }
            Button("Cancel", role: .cancel) { safeDeleteTarget = nil }
        } message: {
            Text("The screenshot is removed from Photos. The extracted text stays in RecallThat.")
        }
        .confirmationDialog(
            "Safe Delete \(viewModel.selectedIDs.count) Screenshot\(viewModel.selectedIDs.count == 1 ? "" : "s")?",
            isPresented: $showBatchSafeDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete from Photos", role: .destructive) {
                Task {
                    await viewModel.safeDeleteSelected(
                        photoService: appEnv.photoLibraryService,
                        repository: appEnv.memoryRepository
                    )
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Original screenshots are removed from Photos. Extracted text stays searchable in RecallThat.")
        }
        .confirmationDialog(
            "Delete \(viewModel.selectedIDs.count) Memor\(viewModel.selectedIDs.count == 1 ? "y" : "ies") Forever?",
            isPresented: $showBatchHardDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Forever", role: .destructive) {
                Task {
                    await viewModel.hardDeleteSelected(
                        photoService: appEnv.photoLibraryService,
                        repository: appEnv.memoryRepository
                    )
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the memories and their original screenshots from RecallThat. This cannot be undone.")
        }
    }

    // MARK: - Authorized content

    @ViewBuilder
    private var authorizedContent: some View {
        if viewModel.isLoading {
            ProgressView("Loading…")
        } else if let error = viewModel.errorMessage {
            errorView(message: error)
        } else if viewModel.memories.isEmpty {
            emptyView
        } else {
            memoriesList
        }
    }

    private var memoriesList: some View {
        List {
            ForEach(viewModel.memories) { memory in
                if viewModel.isSelecting {
                    Button {
                        viewModel.toggleSelection(memory.id)
                    } label: {
                        MemoryCardView(
                            memory: memory,
                            isSelecting: true,
                            isSelected: viewModel.selectedIDs.contains(memory.id)
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink(destination: MemoryDetailView(memory: memory)) {
                        MemoryCardView(memory: memory)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if memory.originalExists && memory.sourceType == .screenshot {
                            Button {
                                safeDeleteTarget = memory
                            } label: {
                                Label("Safe Delete", systemImage: "photo.badge.minus")
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay(alignment: .bottom) {
            if viewModel.isSelecting && !viewModel.selectedIDs.isEmpty {
                batchActionBar
            }
        }
    }

    private var batchActionBar: some View {
        let hasOriginals = viewModel.memories.contains {
            viewModel.selectedIDs.contains($0.id) && $0.originalExists && $0.sourceType == .screenshot
        }

        return HStack(spacing: 12) {
            if hasOriginals {
                Button {
                    showBatchSafeDeleteConfirm = true
                } label: {
                    Label("Safe Delete (\(viewModel.selectedIDs.count))", systemImage: "photo.badge.minus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }

            Button {
                showBatchHardDeleteConfirm = true
            } label: {
                Label("Delete (\(viewModel.selectedIDs.count))", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    private var emptyView: some View {
        ContentUnavailableView(
            "No screenshots found",
            systemImage: "rectangle.stack",
            description: Text("Pull down to refresh, or check that RecallThat has Full Access in Settings → Privacy → Photos.")
        )
    }

    private func errorView(message: String) -> some View {
        ContentUnavailableView(
            "Something went wrong",
            systemImage: "exclamationmark.triangle",
            description: Text(message)
        )
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if viewModel.isSelecting {
                Button("Cancel") {
                    viewModel.toggleSelecting()
                }
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            if viewModel.isSelecting {
                Button("Select All") {
                    viewModel.selectAll()
                }
            } else if viewModel.isImporting {
                HStack(spacing: 6) {
                    ProgressView()
                    Text("Importing…").font(.caption)
                }
            } else if viewModel.isRunningOCR, let progress = viewModel.ocrProgress {
                HStack(spacing: 6) {
                    ProgressView()
                    Text(progress.description).font(.caption)
                }
            } else if viewModel.memories.contains(where: { $0.ocrStatus == .failed }) {
                Button {
                    Task {
                        await viewModel.retryFailedOCR(
                            using: appEnv.ocrPipelineService,
                            repository: appEnv.memoryRepository
                        )
                    }
                } label: {
                    Label("Retry Failed", systemImage: "arrow.clockwise")
                }
            } else if !viewModel.memories.isEmpty {
                Button("Select") {
                    viewModel.toggleSelecting()
                }
            }
        }
    }

    // MARK: - Sync

    private func runFullSync() async {
        await viewModel.load(from: appEnv.memoryRepository)
        guard viewModel.permissionStatus == .authorized || viewModel.permissionStatus == .limited else { return }
        await viewModel.importScreenshots(using: appEnv.photoImportService, repository: appEnv.memoryRepository)
        await viewModel.runOCR(using: appEnv.ocrPipelineService, repository: appEnv.memoryRepository)
    }
}
