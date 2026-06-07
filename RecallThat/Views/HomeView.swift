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
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
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
        // Safe Delete (single) — removes photo from Photos, text stays
        .alert("Safe Delete?", isPresented: .init(
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
            Text("The photo is removed from your Photos library. The extracted text stays in RecallThat — you can still search for this memory.")
        }
        // Full Delete (single) — removes everything permanently
        .alert("Full Delete?", isPresented: .init(
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
        // Batch safe delete — centered alert, single Photos permission prompt
        .alert(
            "Safe Delete \(viewModel.selectedIDs.count) Screenshot\(viewModel.selectedIDs.count == 1 ? "" : "s")?",
            isPresented: $showBatchSafeDeleteConfirm
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
            Text("Photos are removed from your library in one step. Extracted text stays searchable in RecallThat.")
        }
        // Batch full delete — centered alert
        .alert(
            "Full Delete \(viewModel.selectedIDs.count) Memor\(viewModel.selectedIDs.count == 1 ? "y" : "ies")?",
            isPresented: $showBatchHardDeleteConfirm
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
            ForEach(viewModel.groupedMemories, id: \.label) { group in
                Section(group.label) {
                    ForEach(group.memories) { memory in
                        memoryRow(for: memory)
                    }
                }
            }
        }
        .listStyle(.plain)
        .listRowSpacing(0)
        .overlay(alignment: .bottom) {
            if viewModel.isSelecting && !viewModel.selectedIDs.isEmpty {
                batchActionBar
            }
        }
    }

    @ViewBuilder
    private func memoryRow(for memory: Memory) -> some View {
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
                        Label("Safe\nDelete", systemImage: "trash")
                    }
                    .tint(.green)
                }
                Button(role: .destructive) {
                    hardDeleteTarget = memory
                } label: {
                    Label("Full\nDelete", systemImage: "trash.fill")
                }
            }
        }
    }

    // MARK: - Batch action bar

    private var batchActionBar: some View {
        let hasOriginals = viewModel.memories.contains {
            viewModel.selectedIDs.contains($0.id) && $0.originalExists && $0.sourceType == .screenshot
        }

        return HStack(spacing: 0) {
            if hasOriginals {
                Button {
                    showBatchSafeDeleteConfirm = true
                } label: {
                    Label("Safe Delete", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .foregroundStyle(.green)

                Divider().frame(height: 22)
            }

            Button {
                showBatchHardDeleteConfirm = true
            } label: {
                Label("Full Delete", systemImage: "trash.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .foregroundStyle(.red)
        }
        .font(.subheadline.weight(.medium))
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
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
            } else {
                HStack(spacing: 8) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    Text("RecallThat")
                        .font(.headline)
                        .fontWeight(.bold)
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
            } else if viewModel.isRunningOCR {
                HStack(spacing: 6) {
                    ProgressView()
                    if let progress = viewModel.ocrProgress {
                        Text(progress.description).font(.caption)
                    } else {
                        Text("Indexing…").font(.caption)
                    }
                }
            } else if !viewModel.memories.isEmpty {
                Menu {
                    if viewModel.memories.contains(where: { $0.ocrStatus == .failed }) {
                        Button {
                            Task {
                                await viewModel.retryFailedOCR(
                                    using: appEnv.ocrPipelineService,
                                    repository: appEnv.memoryRepository
                                )
                            }
                        } label: {
                            Label("Retry Failed", systemImage: "arrow.clockwise.circle")
                        }
                    }
                    Button {
                        viewModel.toggleSelecting()
                    } label: {
                        Label("Select", systemImage: "checkmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel("More options")
                }
            }
        }
    }

    // MARK: - Sync

    private func runFullSync() async {
        await viewModel.load(from: appEnv.memoryRepository)
        guard viewModel.permissionStatus == .authorized || viewModel.permissionStatus == .limited else { return }
        await viewModel.importScreenshots(using: appEnv.photoImportService, repository: appEnv.memoryRepository)
        await viewModel.resetFailedItems(in: appEnv.memoryRepository)
        await viewModel.runOCR(using: appEnv.ocrPipelineService, repository: appEnv.memoryRepository)
        Task { await appEnv.embeddingPipelineService.processQueue() }
    }
}
