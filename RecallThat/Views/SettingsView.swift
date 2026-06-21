import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @State private var showDeleteAllConfirmation = false
    @State private var showDeletedAllAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Build", value: appBuild)
                }

                Section("Privacy") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What RecallThat stores locally:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Group {
                            Label("Screenshot text (OCR)", systemImage: "text.alignleft")
                            Label("Screenshot date and title", systemImage: "calendar")
                            Label("Small thumbnail (when available)", systemImage: "photo")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    Text("Your photos never leave your device. OCR runs on-device using Apple Vision. Extracted text may be sent to OpenAI's servers to power semantic search and AI answers. RecallThat has no backend server and no account system.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Photos Access") {
                    Text("RecallThat only reads screenshot assets. It cannot access non-screenshot photos unless you explicitly grant full library access.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("Open Settings") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                }

                Section {
                    HStack {
                        Label("Semantic Search", systemImage: "sparkles")
                        Spacer()
                        Text(APIConfig.hasOpenAIKey ? "On" : "Unavailable")
                            .foregroundStyle(APIConfig.hasOpenAIKey ? .green : .secondary)
                            .fontWeight(.medium)
                    }
                    HStack {
                        Label("AI Answers", systemImage: "brain")
                        Spacer()
                        Text(APIConfig.hasOpenAIKey ? "On" : "Unavailable")
                            .foregroundStyle(APIConfig.hasOpenAIKey ? .green : .secondary)
                            .fontWeight(.medium)
                    }
                } header: {
                    Text("AI Search")
                } footer: {
                    Text("Semantic search and AI-powered answers use the configured OpenAI API key. Keyword search is always available as a fallback.")
                }

                Section("Data Management") {
                    Button("Delete All Memories", role: .destructive) {
                        showDeleteAllConfirmation = true
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Delete All Memories?",
                isPresented: $showDeleteAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete All Memories", role: .destructive) {
                    Task { await deleteAll() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All indexed text, titles, and thumbnails will be removed from RecallThat. Your original screenshots in Photos are not affected.")
            }
            .alert("All memories deleted.", isPresented: $showDeletedAllAlert) {
                Button("OK") {}
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    private func deleteAll() async {
        guard let all = try? await appEnv.memoryRepository.fetchAll() else { return }
        for memory in all {
            try? await appEnv.memoryRepository.delete(id: memory.id)
        }
        appEnv.memoriesVersion += 1
        showDeletedAllAlert = true
    }
}
