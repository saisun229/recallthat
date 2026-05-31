import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading memories…")
                } else if viewModel.memories.isEmpty {
                    emptyState
                } else {
                    memoriesList
                }
            }
            .navigationTitle("RecallThat")
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
