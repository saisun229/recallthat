import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @State private var showDeleteAllConfirmation = false
    @State private var showDeletedAllAlert = false
    @State private var apiKeyInput: String = ""
    @State private var apiKeySaved = false
    @State private var showKey = false

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

                    Text("Nothing is uploaded. OCR runs on-device using Apple Vision. RecallThat has no backend server and no account system.")
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

                // MARK: - OpenAI API Key
                Section {
                    HStack {
                        Label("Status", systemImage: "sparkles")
                        Spacer()
                        if APIConfig.hasOpenAIKey {
                            Text("Connected")
                                .foregroundStyle(.green)
                                .fontWeight(.medium)
                        } else {
                            Text("Not configured")
                                .foregroundStyle(.orange)
                                .fontWeight(.medium)
                        }
                    }

                    HStack(spacing: 8) {
                        Group {
                            if showKey {
                                TextField("sk-...", text: $apiKeyInput)
                            } else {
                                SecureField("sk-...", text: $apiKeyInput)
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))

                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack {
                        Button("Save Key") {
                            APIConfig.saveOpenAIKey(apiKeyInput)
                            apiKeySaved = true
                            apiKeyInput = ""
                            // Kick off embedding for any items waiting on a key
                            appEnv.startEmbeddingIfNeeded()
                        }
                        .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Spacer()

                        if APIConfig.hasOpenAIKey {
                            Button("Remove Key", role: .destructive) {
                                APIConfig.deleteOpenAIKey()
                                apiKeyInput = ""
                                apiKeySaved = false
                            }
                        }
                    }

                    if apiKeySaved {
                        Label("Key saved to Keychain.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }

                } header: {
                    Text("OpenAI API Key (BYOK)")
                } footer: {
                    Text("Paste your OpenAI key to enable semantic search and AI answers. The key is stored on-device in the iOS Keychain and never sent to any server other than api.openai.com.")
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
