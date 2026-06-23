import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentPage = 0

    private let consentPageIndex = 1

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            systemImage: "text.magnifyingglass",
            color: .blue,
            title: "Find What You Forgot",
            body: "RecallThat turns your screenshots into searchable memory. Type anything you remember and find it instantly."
        ),
        OnboardingPage(
            systemImage: "lock.shield.fill",
            color: .green,
            title: "Your Photos Stay Private",
            body: "Text is extracted using Apple's on-device OCR. Your photos never leave your device.\n\nTo power semantic search and AI-powered answers, the extracted text (not your photos) can be sent to OpenAI, RecallThat's AI provider. This is optional — you choose below, and you can change it anytime in Settings."
        ),
        OnboardingPage(
            systemImage: "photo.badge.minus",
            color: .orange,
            title: "Delete Clutter Anytime",
            body: "Once indexed, delete the original from Photos. The extracted text and title stay in RecallThat so you can always search for it."
        ),
    ]

    var body: some View {
        ZStack {
            // Animated gradient tint shifts with each page
            LinearGradient(
                colors: [pages[currentPage].color.opacity(0.18), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.45), value: currentPage)

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        pageView(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Group {
                    if currentPage == consentPageIndex {
                        consentButtons
                    } else {
                        actionButton
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 52)
                .padding(.top, 12)
            }
        }
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 0) {
            Spacer()

            // Layered circle icon
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.12))
                    .frame(width: 160, height: 160)
                Circle()
                    .fill(page.color.opacity(0.18))
                    .frame(width: 116, height: 116)
                Image(systemName: page.systemImage)
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(page.color)
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(.bottom, 36)

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }

    private var actionButton: some View {
        Button {
            if currentPage < pages.count - 1 {
                withAnimation(.easeInOut(duration: 0.3)) { currentPage += 1 }
            } else {
                onComplete()
            }
        } label: {
            Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(pages[currentPage].color)
        .animation(.easeInOut(duration: 0.25), value: currentPage)
    }

    private var consentButtons: some View {
        VStack(spacing: 10) {
            Button {
                APIConfig.setUserConsent(true)
                withAnimation(.easeInOut(duration: 0.3)) { currentPage += 1 }
            } label: {
                Text("Allow Sharing with OpenAI")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(pages[currentPage].color)

            Button {
                APIConfig.setUserConsent(false)
                withAnimation(.easeInOut(duration: 0.3)) { currentPage += 1 }
            } label: {
                Text("Keep On-Device Only")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderless)
        }
        .animation(.easeInOut(duration: 0.25), value: currentPage)
    }
}

private struct OnboardingPage {
    let systemImage: String
    let color: Color
    let title: String
    let body: String
}
