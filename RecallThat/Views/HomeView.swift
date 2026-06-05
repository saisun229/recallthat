import SwiftUI
@preconcurrency import Photos

struct HomeView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @State private var viewModel = HomeViewModel()
    @State private var safeDeleteTarget: Memory? = nil
    @State private var hardDeleteTarget: Memory? = nil
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
        // Safe Delete confirmation — removes photo from Photos, keeps text
        .alert("Delete Original Photo?", isPresented: .init(
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
            Text("The original photo is removed from your Photos library. The extracted text stays in RecallThat — you can still search for this memory.")
        }
        // Hard Delete confirmation — removes everything permanently
        .alert("Delete Memory Forever?", isPresented: .init(
            get: { hardDeleteTarget != nil },
            set: { if !$0 { hardDeleteTarget = nil } }
        )) {
            Button("Delete Forever", role: .destructive) {
                guard let target = hardDeleteTarget else { return }
                hardDeleteTarget = nil
                Task {
                    viewModel.selectedIDs = [target.id]
                    await viewModel.hardDeleteSelected(
                        photoService: appEnv.photoLibraryService,
                        repository: appEnv.memoryRepository
                    )
                }
            }
            Button("Cancel", role: .cancel) { hardDeleteTarget = nil }
        } message: {
            Text("Removes the memory and its original photo from RecallThat completely. This cannot be undone.")
        }
        // Batch safe delete
        .confirmationDialog(
            "Delete Photos for \(viewModel.selectedIDs.count) Screenshot\(viewModel.selectedIDs.count == 1 ? "" : "s")?",
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
            Text("Original photos are removed from your Photos library. Extracted text stays searchable in RecallThat.")
        }
        // Batch hard delete
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
            Text("Permanently removes the memories and original photos from RecallThat. This cannot be undone.")
        }
    }

    // MARK: - Authorized content

    @ViewBuilder
    private var authorizedContent: some View {
        if viewModel.isLoading {
            ProgressView("Loading…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage {
            errorView(message: error)
        } else if viewModel.memories.isEmpty {
            emptyView
        } else {
            memoriesList
        }
    }

    // MARK: - Memories list

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
                        // Orange: safe delete — photo gone, text stays
                        if memory.originalExists && memory.sourceType == .screenshot {
                            Button {
                                safeDeleteTarget = memory
                            } label: {
                                Label("Delete\nPhoto", systemImage: "photo.badge.minus")
                            }
                            .tint(.orange)
                        }
                        // Red: hard delete — removes everything permanently
                        Button(role: .destructive) {
                            hardDeleteTarget = memory
                        } label: {
                            Label("Delete\nForever", systemImage: "trash.fill")
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

    // MARK: - Batch action bar

    private var batchActionBar: some View {
        let hasOriginals = viewModel.memories.contains {
            viewModel.selectedIDs.contains($0.id) && $0.originalExists && $0.sourceType == .screenshot
        }
        let count = viewModel.selectedIDs.count

        return VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                if hasOriginals {
                    Button {
                        showBatchSafeDeleteConfirm = true
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "photo.badge.minus")
                                .font(.title3)
                            Text("Delete Photos")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("text stays")
                                .font(.caption2)
                                .opacity(0.75)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }

                Button {
                    showBatchHardDeleteConfirm = true
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "trash.fill")
                            .font(.title3)
                        Text("Delete Forever")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("\(count) item\(count == 1 ? "" : "s")")
                            .font(.caption2)
                            .opacity(0.75)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .padding(.bottom, 4)
            .background(.regularMaterial)
        }
    }

    // MARK: - Empty / error states

    private var emptyView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.08))
                    .frame(width: 120, height: 120)
                Image(systemName: "photo.stack")
                    .font(.system(size: 52, weight: .ultraLight))
                    .foregroundStyle(Color.accentColor.opacity(0.7))
            }

            VStack(spacing: 8) {
                Text("No Memories Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Take a screenshot. Open RecallThat.\nText is indexed automatically.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await runFullSync() }
            } label: {
                Label("Sync Now", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.bordered)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                Button {
                    viewModel.toggleSelecting()
                } label: {
                    Image(systemName: "checkmark.circle")
                        .accessibilityLabel("Select memories")
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
