import SwiftUI
import UIKit

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
                } else if !viewModel.isSearching && viewModel.results.isEmpty {
                    ContentUnavailableView.search(text: viewModel.query)
                } else {
                    List {
                        ForEach(viewModel.results) { resultRow(for: $0) }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $viewModel.query, prompt: "Search memories…")
            .onChange(of: viewModel.query) { _, _ in
                viewModel.search(using: appEnv.searchService)
            }
            .toolbar {
                if viewModel.isSearching {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ProgressView()
                    }
                }
            }
        }
        .task {
            await viewModel.loadMemories(from: appEnv.memoryRepository)
        }
        .onAppear {
            Task { await viewModel.loadMemories(from: appEnv.memoryRepository) }
        }
        .onChange(of: appEnv.memoriesVersion) { _, _ in
            Task { await viewModel.loadMemories(from: appEnv.memoryRepository) }
        }
    }

    // MARK: - Result row

    @ViewBuilder
    private func resultRow(for memory: Memory) -> some View {
        NavigationLink(destination: MemoryDetailView(memory: memory)) {
            MemoryCardView(memory: memory)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if memory.sourceType == .sharedURL,
               let urlStr = memory.sourceURL,
               let url = URL(string: urlStr) {
                let source = URLSourceType.detect(from: urlStr)
                Button {
                    UIApplication.shared.open(url)
                } label: {
                    Label(source.displayName, systemImage: source.systemIcon)
                }
                .tint(source.accentColor)
            }
        }
    }
}
