import SwiftUI
import Photos

struct HomeView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @State private var viewModel = HomeViewModel()

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
        .refreshable {
            await runFullSync()
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
        List(viewModel.memories) { memory in
            NavigationLink(destination: MemoryDetailView(memory: memory)) {
                MemoryCardView(memory: memory)
            }
        }
        .listStyle(.plain)
    }

    private var emptyView: some View {
        ContentUnavailableView(
            "No screenshots found",
            systemImage: "rectangle.stack",
            description: Text("Screenshots from your Photos library will appear here once indexed.")
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
        ToolbarItem(placement: .navigationBarTrailing) {
            if viewModel.isImporting {
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
