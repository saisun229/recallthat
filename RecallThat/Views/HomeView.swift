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
            .toolbar {
                if viewModel.isImporting {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ProgressView()
                    }
                }
            }
        }
        .task {
            await viewModel.load(from: appEnv.memoryRepository)
            if viewModel.permissionStatus == .authorized || viewModel.permissionStatus == .limited {
                await viewModel.importScreenshots(
                    using: appEnv.photoImportService,
                    repository: appEnv.memoryRepository
                )
            }
        }
        .onChange(of: viewModel.permissionStatus) { _, newStatus in
            guard newStatus == .authorized || newStatus == .limited else { return }
            Task {
                await viewModel.importScreenshots(
                    using: appEnv.photoImportService,
                    repository: appEnv.memoryRepository
                )
            }
        }
    }

    @ViewBuilder
    private var authorizedContent: some View {
        if viewModel.isLoading {
            ProgressView("Loading…")
        } else if let error = viewModel.errorMessage {
            ContentUnavailableView(
                "Something went wrong",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
        } else if viewModel.memories.isEmpty {
            ContentUnavailableView(
                "No screenshots found",
                systemImage: "rectangle.stack",
                description: Text("Screenshots from your Photos library will appear here.")
            )
        } else {
            List(viewModel.memories) { memory in
                NavigationLink(destination: MemoryDetailView(memory: memory)) {
                    MemoryCardView(memory: memory)
                }
            }
            .listStyle(.plain)
        }
    }
}
