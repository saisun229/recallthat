import SwiftUI

struct HomeView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @State private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading memories…")
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Something went wrong",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if viewModel.memories.isEmpty {
                    emptyState
                } else {
                    memoriesList
                }
            }
            .navigationTitle("RecallThat")
        }
        .task {
            await viewModel.load(from: appEnv.memoryRepository)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No memories yet",
            systemImage: "rectangle.stack",
            description: Text("Screenshots you index will appear here.")
        )
    }

    private var memoriesList: some View {
        List(viewModel.memories) { memory in
            NavigationLink(destination: MemoryDetailView(memory: memory)) {
                MemoryCardView(memory: memory)
            }
        }
        .listStyle(.plain)
    }
}
