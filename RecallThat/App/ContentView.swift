import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Memories", systemImage: "photo.stack.fill") }

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            ChatView()
                .tabItem { Label("Ask", systemImage: "bubble.left.and.bubble.right.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}
