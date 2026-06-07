import SwiftUI

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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(ChatQueryCounter.queriesRemaining)/\(ChatQueryCounter.limitPerDay) today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            if viewModel.messages.isEmpty {
                viewModel.messages.append(ChatMessage(
                    isUser: false,
                    content: "Ask me anything about your saved memories. I'll search through them and give you a direct answer."
                ))
            }
        }
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
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
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
