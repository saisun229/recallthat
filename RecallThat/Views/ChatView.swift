import SwiftUI
import UIKit

struct ChatView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @State private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // OpenAI connectivity error — dismissable banner
                if let err = viewModel.openAIError {
                    openAIErrorBanner(message: err)
                }

                messageList
                Divider()
                inputBar
            }
            .navigationTitle("Ask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isInputFocused = false
                        viewModel.startNewConversation()
                        addWelcomeMessageIfNeeded()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .disabled(viewModel.isResponding)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(ChatQueryCounter.queriesRemaining)/\(ChatQueryCounter.limitPerDay) today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            addWelcomeMessageIfNeeded()
        }
    }

    private func addWelcomeMessageIfNeeded() {
        guard viewModel.messages.isEmpty else { return }
        viewModel.messages.append(ChatMessage(
            isUser: false,
            content: "Ask me anything about your saved memories. I'll search through them and give you a direct answer."
        ))
    }

    // MARK: - Error banner

    private func openAIErrorBanner(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.subheadline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer()
            Button {
                viewModel.dismissOpenAIError()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.12))
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { msg in
                        ChatBubble(message: msg)
                            .id(msg.id)
                    }
                    if viewModel.isResponding {
                        TypingIndicator()
                            .id("typing")
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom") }
            }
            .onChange(of: viewModel.isResponding) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom") }
            }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            if let err = viewModel.limitError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask about your memories…", text: $viewModel.inputText, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 20))
                    .submitLabel(.send)
                    .focused($isInputFocused)
                    .onSubmit { sendMessage() }

                Button { sendMessage() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(canSend ? .blue : Color.secondary.opacity(0.35))
                }
                .disabled(!canSend)
                .padding(.bottom, 2)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    private var canSend: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty && !viewModel.isResponding
    }

    private func sendMessage() {
        guard canSend else { return }
        isInputFocused = false // Dismiss keyboard immediately before the async call
        Task { await viewModel.send(using: appEnv.searchService, repository: appEnv.memoryRepository) }
    }
}

// MARK: - Chat bubble

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
            HStack(alignment: .bottom) {
                if message.isUser { Spacer(minLength: 48) }
                Text(message.content)
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(message.isUser ? Color.blue : Color(.systemGray5))
                    .foregroundStyle(message.isUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .textSelection(.enabled)
                if !message.isUser { Spacer(minLength: 48) }
            }

            if !message.sources.isEmpty {
                sourcesRow
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }

    private var sourcesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(message.sources.enumerated()), id: \.element.id) { index, memory in
                    NavigationLink(destination: MemoryDetailView(memory: memory)) {
                        ChatSourceCard(index: index + 1, memory: memory)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.trailing, 48)
        }
    }
}

// MARK: - Source card

/// Tappable thumbnail card shown under an assistant message, mirroring the homepage's
/// memory thumbnail so a citation like [1] can be opened straight into MemoryDetailView.
struct ChatSourceCard: View {
    let index: Int
    let memory: Memory

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topLeading) {
                thumbnailView
                Text("\(index)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(Color.black.opacity(0.55), in: Circle())
                    .padding(4)
            }

            Text(displayTitle)
                .font(.caption2)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(width: 76, alignment: .leading)
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let identifier = memory.photoAssetIdentifier {
            AssetThumbnailView(identifier: identifier, size: 76)
        } else if let path = memory.localThumbnailPath,
                  let uiImage = UIImage(contentsOfFile: path) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.1))
                .frame(width: 76, height: 76)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundStyle(.tertiary)
                )
        }
    }

    private var displayTitle: String {
        memory.title.isEmpty
            ? memory.createdAt.formatted(date: .abbreviated, time: .omitted)
            : memory.title
    }
}

// MARK: - Typing indicator

struct TypingIndicator: View {
    @State private var phase = 0
    let timer = Timer.publish(every: 0.45, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary.opacity(i == phase ? 0.9 : 0.25))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: phase)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .frame(maxWidth: .infinity, alignment: .leading)
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
    }
}
