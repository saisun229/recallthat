import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            systemImage: "magnifyingglass",
            title: "Find what you forgot",
            body: "RecallThat turns your screenshots into searchable memory. Type anything you remember and find it instantly."
        ),
        OnboardingPage(
            systemImage: "lock.shield",
            title: "Everything stays on your device",
            body: "Text is extracted using Apple's on-device OCR. Your screenshots and their contents are never uploaded or shared."
        ),
        OnboardingPage(
            systemImage: "trash",
            title: "Delete clutter when you're ready",
            body: "Once a screenshot is indexed you can delete the original from Photos. The text, title, and date stay in RecallThat so you can always search for it."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            actionButton
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
                .padding(.top, 16)
        }
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: page.systemImage)
                .font(.system(size: 72, weight: .thin))
                .foregroundStyle(.tint)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text(page.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }

    private var actionButton: some View {
        Button {
            if currentPage < pages.count - 1 {
                withAnimation { currentPage += 1 }
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
        .animation(.none, value: currentPage)
    }
}

private struct OnboardingPage {
    let systemImage: String
    let title: String
    let body: String
}
