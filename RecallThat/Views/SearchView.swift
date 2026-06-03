import SwiftUI

struct SearchView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @State private var viewModel = SearchViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.query.isEmpty {
                    ContentUnavailableView(
                        "Search your memories",
                        systemImage: "magnifyingglass",
                        description: Text("Type something you remember from a screenshot.")
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
            .searchable(text: $viewModel.query, prompt: "Search your memories…")
            .onChange(of: viewModel.query) { _, _ in
                viewModel.search(using: appEnv.searchService)
            }
        }
        .task {
            await viewModel.loadMemories(from: appEnv.memoryRepository)
        }
    }
}
