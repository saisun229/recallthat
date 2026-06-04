import UIKit
import SwiftUI
import SwiftData
import Vision
import UniformTypeIdentifiers

// MARK: - Observable state shared between UIKit controller and SwiftUI view

@Observable
final class ShareState {
    enum Phase { case processing, saved, failed }
    var phase: Phase = .processing
}

// MARK: - ShareViewController

final class ShareViewController: UIViewController {

    private let shareState = ShareState()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let shareView = ShareExtensionView(
            state: shareState,
            onCancel: { [weak self] in
                self?.extensionContext?.cancelRequest(withError: CancellationError())
            }
        )
        let hosting = UIHostingController(rootView: shareView)
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        hosting.didMove(toParent: self)

        Task { await processSharedContent() }
    }

    // MARK: - Dispatch by content type

    private func processSharedContent() async {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            fail(); return
        }
        for item in items {
            for attachment in item.attachments ?? [] {
                if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    await handleImage(attachment); return
                }
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    await handleURL(attachment); return
                }
                if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    await handleText(attachment); return
                }
            }
        }
        fail()
    }

    // MARK: - Image handler

    private func handleImage(_ provider: NSItemProvider) async {
        do {
            let raw = try await provider.loadItem(forTypeIdentifier: UTType.image.identifier)
            let image: UIImage? = {
                if let ui = raw as? UIImage    { return ui }
                if let url = raw as? URL       { return UIImage(contentsOfFile: url.path) }
                if let data = raw as? Data     { return UIImage(data: data) }
                return nil
            }()
            guard let image else { fail(); return }

            let text = (try? await recognizeText(in: image)) ?? ""
            let firstLine = text.components(separatedBy: "\n")
                .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let title = firstLine ?? "Shared Image"
            let id = UUID()

            try save(MemoryPayload(
                id: id,
                sourceType: .sharedImage,
                title: title,
                ocrText: text,
                thumbnailPath: saveThumbnail(image, id: id),
                sourceURL: nil
            ))
            succeed()
        } catch {
            fail()
        }
    }

    // MARK: - URL handler

    private func handleURL(_ provider: NSItemProvider) async {
        do {
            let raw = try await provider.loadItem(forTypeIdentifier: UTType.url.identifier)
            guard let url = raw as? URL else { fail(); return }

            let meta = await fetchMetadata(for: url)
            let title = meta.title ?? url.host ?? url.absoluteString
            let text = [title, meta.description].compactMap { $0 }.joined(separator: "\n")
            let id = UUID()
            var thumbPath: String? = nil
            if let imgURL = meta.imageURL {
                thumbPath = await downloadThumbnail(from: imgURL, id: id)
            }

            try save(MemoryPayload(
                id: id,
                sourceType: .sharedURL,
                title: title,
                ocrText: text,
                thumbnailPath: thumbPath,
                sourceURL: url.absoluteString
            ))
            succeed()
        } catch {
            fail()
        }
    }

    // MARK: - Text handler

    private func handleText(_ provider: NSItemProvider) async {
        do {
            let raw = try await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier)
            guard let text = raw as? String, !text.isEmpty else { fail(); return }

            let firstLine = text.components(separatedBy: "\n")
                .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let title = String((firstLine ?? text).prefix(80))
            let id = UUID()

            try save(MemoryPayload(
                id: id,
                sourceType: .sharedText,
                title: title,
                ocrText: text,
                thumbnailPath: nil,
                sourceURL: nil
            ))
            succeed()
        } catch {
            fail()
        }
    }

    // MARK: - Vision OCR

    private func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { return "" }
        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([request])
            return (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
        }.value
    }

    // MARK: - URL metadata

    private struct PageMetadata {
        var title: String?
        var description: String?
        var imageURL: URL?
    }

    private func fetchMetadata(for url: URL) async -> PageMetadata {
        if let videoID = youTubeVideoID(from: url) {
            return await youTubeMetadata(videoID: videoID)
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let html = String(data: data, encoding: .utf8)
                      ?? String(data: data, encoding: .isoLatin1) else {
            return PageMetadata(title: url.host, description: nil, imageURL: nil)
        }
        return parseHTML(html, baseURL: url)
    }

    private func youTubeVideoID(from url: URL) -> String? {
        guard let host = url.host,
              host.contains("youtube.com") || host.contains("youtu.be") else { return nil }
        if host.contains("youtu.be") { return url.lastPathComponent.isEmpty ? nil : url.lastPathComponent }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "v" })?.value
    }

    private func youTubeMetadata(videoID: String) async -> PageMetadata {
        let thumbURL = URL(string: "https://img.youtube.com/vi/\(videoID)/hqdefault.jpg")
        if let oembedURL = URL(string: "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=\(videoID)&format=json"),
           let (data, _) = try? await URLSession.shared.data(from: oembedURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let title = json["title"] as? String {
            return PageMetadata(title: title, description: nil, imageURL: thumbURL)
        }
        return PageMetadata(title: "YouTube Video", description: nil, imageURL: thumbURL)
    }

    private func parseHTML(_ html: String, baseURL: URL) -> PageMetadata {
        func metaContent(_ property: String) -> String? {
            let patterns = [
                "property=[\"']\(NSRegularExpression.escapedPattern(for: property))[\"'][^>]*content=[\"']([^\"'<>]+)[\"']",
                "content=[\"']([^\"'<>]+)[\"'][^>]*property=[\"']\(NSRegularExpression.escapedPattern(for: property))[\"']",
                "name=[\"']\(NSRegularExpression.escapedPattern(for: property))[\"'][^>]*content=[\"']([^\"'<>]+)[\"']",
                "content=[\"']([^\"'<>]+)[\"'][^>]*name=[\"']\(NSRegularExpression.escapedPattern(for: property))[\"']",
            ]
            for pattern in patterns {
                guard let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                      let m = re.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                      let r = Range(m.range(at: 1), in: html) else { continue }
                return String(html[r])
            }
            return nil
        }

        func pageTitle() -> String? {
            guard let re = try? NSRegularExpression(pattern: "<title[^>]*>([^<]+)</title>", options: .caseInsensitive),
                  let m = re.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                  let r = Range(m.range(at: 1), in: html) else { return nil }
            return String(html[r]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let imageStr = metaContent("og:image")
        let imageURL: URL? = imageStr.flatMap {
            URL(string: $0) ?? URL(string: $0, relativeTo: baseURL)?.absoluteURL
        }
        return PageMetadata(
            title: metaContent("og:title") ?? pageTitle(),
            description: metaContent("og:description"),
            imageURL: imageURL
        )
    }

    // MARK: - Thumbnails

    private var thumbnailDirectory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.recallthat.app")?
            .appendingPathComponent("thumbnails")
    }

    private func saveThumbnail(_ image: UIImage, id: UUID) -> String? {
        guard let dir = thumbnailDirectory else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("\(id.uuidString).jpg")
        let resized = resized(image, maxDimension: 200)
        guard let data = resized.jpegData(compressionQuality: 0.75) else { return nil }
        try? data.write(to: fileURL)
        return fileURL.path
    }

    private func downloadThumbnail(from url: URL, id: UUID) async -> String? {
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else { return nil }
        return saveThumbnail(image, id: id)
    }

    private func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        guard ratio < 1 else { return image }
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - Persistence

    private struct MemoryPayload {
        let id: UUID
        let sourceType: MemorySourceType
        let title: String
        let ocrText: String
        let thumbnailPath: String?
        let sourceURL: String?
    }

    private enum SaveError: Error { case noGroupContainer }

    private func save(_ payload: MemoryPayload) throws {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.recallthat.app"
        ) else { throw SaveError.noGroupContainer }

        let storeURL = groupURL.appendingPathComponent("recallthat.sqlite")
        let config = ModelConfiguration(url: storeURL)
        let container = try ModelContainer(for: MemoryItem.self, configurations: config)
        let context = ModelContext(container)

        let searchText = (payload.title + " " + payload.ocrText).lowercased()
        let item = MemoryItem(
            id: payload.id,
            sourceTypeRaw: payload.sourceType.rawValue,
            photoAssetIdentifier: nil,
            localThumbnailPath: payload.thumbnailPath,
            createdAt: Date(),
            importedAt: Date(),
            title: payload.title,
            ocrText: payload.ocrText,
            ocrStatusRaw: OCRStatus.complete.rawValue,
            searchText: searchText,
            originalExists: false,
            deletedOriginalAt: nil,
            sourceURL: payload.sourceURL
        )
        context.insert(item)
        try context.save()
    }

    // MARK: - State transitions

    private func succeed() {
        shareState.phase = .saved
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            extensionContext?.completeRequest(returningItems: nil)
        }
    }

    private func fail() {
        shareState.phase = .failed
    }
}

// MARK: - SwiftUI view for the extension sheet

private struct ShareExtensionView: View {
    let state: ShareState
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.blue)
                    Text("RecallThat")
                        .font(.headline)
                }
                Spacer()
                Button("Cancel", action: onCancel)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()
            Spacer()

            switch state.phase {
            case .processing:
                VStack(spacing: 16) {
                    ProgressView().scaleEffect(1.5)
                    Text("Saving to RecallThat…")
                        .foregroundStyle(.secondary)
                }
            case .saved:
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.green)
                    Text("Saved to RecallThat")
                        .font(.headline)
                }
            case .failed:
                VStack(spacing: 16) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.red)
                    Text("Could not save")
                        .font(.headline)
                    Text("Please try again.")
                        .foregroundStyle(.secondary)
                    Button("Dismiss", action: onCancel)
                        .padding(.top, 8)
                }
            }

            Spacer()
        }
    }
}
