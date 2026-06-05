import SwiftUI

struct SearchView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @State private var viewModel = SearchViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.query.isEmpty {
                    ContentUnavailableView(
                        "Search Your Memories",
                        systemImage: "text.magnifyingglass",
                        description: Text("Type any text you remember seeing in a screenshot.")
                    )
                } else if viewModel.results.isEmpty {
                    ContentUnavailableView.search(text: viewModel.query)
                } else {
                    List(viewModel.results) { memory in
                        NavigationLink(destination: MemoryDetailView(memory: memory)) {
                            MemoryCardView(memory: memory)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $viewModel.query, prompt: "Search memories…")
            .onChange(of: viewModel.query) { _, _ in
                viewModel.search(using: appEnv.searchService)
            }
        }
        .task {
            await viewModel.loadMemories(from: appEnv.memoryRepository)
        }
        .onAppear {
            Task { await viewModel.loadMemories(from: appEnv.memoryRepository) }
        }
    }
}
