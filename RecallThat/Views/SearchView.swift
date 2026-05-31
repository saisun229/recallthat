import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.query.isEmpty {
                    emptyPrompt
                } else if viewModel.results.isEmpty {
                    ContentUnavailableView.search(text: viewModel.query)
                } else {
                    resultsList
                }
            }
            .navigationTitle("Search")
            .searchable(text: $viewModel.query, prompt: "Search your memories…")
        }
    }

    private var emptyPrompt: some View {
        ContentUnavailableView(
            "Search your memories",
            systemImage: "magnifyingglass",
            description: Text("Type something you remember from a screenshot.")
        )
    }

    private var resultsList: some View {
        List(viewModel.results) { memory in
            NavigationLink(destination: MemoryDetailView(memory: memory)) {
                MemoryCardView(memory: memory)
            }
        }
        .listStyle(.plain)
    }
}
