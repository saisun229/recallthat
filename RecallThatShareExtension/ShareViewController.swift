import UIKit
import SwiftUI
import SwiftData
import Vision
import UniformTypeIdentifiers
import AVFoundation
import PDFKit

// MARK: - Observable state shared between UIKit controller and SwiftUI view

@Observable
final class ShareState {
    enum Phase { case processing, saved, failed }
    var phase: Phase = .processing
}

// MARK: - ShareViewController

final class ShareViewController: UIViewController {

    private let shareState = ShareState()

    // Debug tracking — populated during processSharedContent, used by fail()
    private var lastDetectedTypes: [String] = []
    private var lastAttemptedURL: String? = nil
    private var lastAttemptedTitle: String? = nil

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

    private static let wordUTIs = [
        "org.openxmlformats.wordprocessingml.document",
        "com.microsoft.word.doc",
        "com.apple.iwork.pages.sffpages",
    ]
    private static let spreadsheetUTIs = [
        "org.openxmlformats.spreadsheetml.sheet",
        "com.microsoft.excel.xls",
        "com.apple.iwork.numbers.sffnumbers",
    ]
    private static let presentationUTIs = [
        "org.openxmlformats.presentationml.presentation",
        "com.microsoft.powerpoint.ppt",
        "com.apple.iwork.keynote.sffkey",
    ]

    private func processSharedContent() async {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            fail(reason: "No input items from extensionContext"); return
        }

        // Collect every type identifier present — used for debug entries
        var allTypes: [String] = []
        var urlProvider: NSItemProvider? = nil
        var imageProvider: NSItemProvider? = nil
        var pdfProvider: NSItemProvider? = nil
        var videoProvider: NSItemProvider? = nil
        var audioProvider: NSItemProvider? = nil
        var textProvider: NSItemProvider? = nil
        var docProvider: (NSItemProvider, String, String)? = nil

        for item in items {
            for attachment in item.attachments ?? [] {
                allTypes.append(contentsOf: attachment.registeredTypeIdentifiers)
                if urlProvider == nil && attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    urlProvider = attachment
                }
                if textProvider == nil && attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    textProvider = attachment
                }
                if imageProvider == nil && attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    imageProvider = attachment
                }
                if pdfProvider == nil && attachment.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                    pdfProvider = attachment
                }
                if videoProvider == nil && attachment.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    videoProvider = attachment
                }
                if audioProvider == nil && attachment.hasItemConformingToTypeIdentifier(UTType.audio.identifier) {
                    audioProvider = attachment
                }
                if docProvider == nil {
                    for uti in Self.wordUTIs where attachment.hasItemConformingToTypeIdentifier(uti) {
                        docProvider = (attachment, uti, "Document"); break
                    }
                    for uti in Self.spreadsheetUTIs where attachment.hasItemConformingToTypeIdentifier(uti) {
                        docProvider = (attachment, uti, "Spreadsheet"); break
                    }
                    for uti in Self.presentationUTIs where attachment.hasItemConformingToTypeIdentifier(uti) {
                        docProvider = (attachment, uti, "Presentation"); break
                    }
                }
            }
        }

        // Store for debug reporting
        lastDetectedTypes = Array(Set(allTypes)).sorted()

        // If a text provider looks like a URL, promote it to URL handling
        if urlProvider == nil, let tp = textProvider {
            if let raw = try? await tp.loadItem(forTypeIdentifier: UTType.plainText.identifier),
               let str = (raw as? String) ?? (raw as? NSString as String?),
               let url = URL(string: str.trimmingCharacters(in: .whitespacesAndNewlines)),
               url.scheme?.hasPrefix("http") == true {
                await handleURLDirectly(url); return
            }
        }

        // Priority: URL > PDF > video > audio > image > text > document
        if let p = urlProvider                   { await handleURL(p); return }
        if let p = pdfProvider                   { await handleFile(p, sourceType: .sharedPDF, label: "PDF"); return }
        if let p = videoProvider                 { await handleFile(p, sourceType: .sharedVideo, label: "Video"); return }
        if let p = audioProvider                 { await handleFile(p, sourceType: .sharedAudio, label: "Audio"); return }
        if let p = imageProvider                 { await handleImage(p); return }
        if let p = textProvider                  { await handleText(p); return }
        if let (p, uti, label) = docProvider     { await handleDocument(p, typeID: uti, label: label); return }

        for item in items {
            for attachment in item.attachments ?? [] where attachment.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
                await handleDocument(attachment, typeID: UTType.data.identifier, label: "File"); return
            }
        }
        fail(reason: "No recognized content type in: \(lastDetectedTypes.joined(separator: ", "))")
    }

    // MARK: - URL directly (from text-promoted-to-URL path)

    private func handleURLDirectly(_ url: URL) async {
        lastAttemptedURL = url.absoluteString
        let meta = await fetchMetadata(for: url)
        let title = meta.title ?? url.host ?? url.absoluteString
        lastAttemptedTitle = title
        let text = [title, meta.description].compactMap { $0 }.joined(separator: "\n")
        let id = UUID()
        var thumbPath: String? = nil
        if let imgURL = meta.imageURL {
            thumbPath = await downloadThumbnail(from: imgURL, id: id)
        }
        do {
            try save(MemoryPayload(id: id, sourceType: .sharedURL, title: title,
                                  ocrText: text, thumbnailPath: thumbPath, sourceURL: url.absoluteString))
            succeed()
        } catch {
            fail(reason: "Save failed: \(error.localizedDescription)")
        }
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
            guard let image else { fail(reason: "Image provider returned unrecognised type: \(type(of: raw))"); return }

            let text = (try? await recognizeText(in: image)) ?? ""
            let firstLine = text.components(separatedBy: "\n")
                .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let title = firstLine ?? "Shared Image"
            lastAttemptedTitle = title
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
            fail(reason: "Image handler: \(error.localizedDescription)")
        }
    }

    // MARK: - URL handler

    private func handleURL(_ provider: NSItemProvider) async {
        do {
            let raw = try await provider.loadItem(forTypeIdentifier: UTType.url.identifier)

            // Accept both URL and String (some apps return NSString for URL items)
            let url: URL? = {
                if let u = raw as? URL { return u }
                if let s = (raw as? String) ?? (raw as? NSString as String?),
                   let u = URL(string: s.trimmingCharacters(in: .whitespacesAndNewlines)) { return u }
                return nil
            }()
            guard let url, url.scheme?.hasPrefix("http") == true else {
                fail(reason: "URL provider returned non-http value: \(raw ?? "nil")")
                return
            }

            lastAttemptedURL = url.absoluteString
            let meta = await fetchMetadata(for: url)
            let title = meta.title ?? url.host ?? url.absoluteString
            lastAttemptedTitle = title
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
            fail(reason: "URL handler: \(error.localizedDescription)")
        }
    }

    // MARK: - Text handler

    private func handleText(_ provider: NSItemProvider) async {
        do {
            let raw = try await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier)
            guard let text = (raw as? String) ?? (raw as? NSString as String?), !text.isEmpty else {
                fail(reason: "Text provider returned empty or non-string: \(type(of: raw))"); return
            }

            let firstLine = text.components(separatedBy: "\n")
                .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let title = String((firstLine ?? text).prefix(80))
            lastAttemptedTitle = title
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
            fail(reason: "Text handler: \(error.localizedDescription)")
        }
    }

    // MARK: - File handler (PDF, video, audio, generic)

    private func handleFile(_ provider: NSItemProvider, sourceType: MemorySourceType, label: String) async {
        let typeID: String = {
            switch sourceType {
            case .sharedPDF:   return UTType.pdf.identifier
            case .sharedVideo: return UTType.movie.identifier
            case .sharedAudio: return UTType.audio.identifier
            default:           return UTType.data.identifier
            }
        }()

        do {
            let raw = try await provider.loadItem(forTypeIdentifier: typeID)
            let fileURL: URL? = raw as? URL
            let filename = fileURL?.deletingPathExtension().lastPathComponent
            let title = filename?.isEmpty == false ? filename! : "Shared \(label)"
            lastAttemptedTitle = title
            let id = UUID()
            var ocrText = ""
            var thumbPath: String? = nil

            if sourceType == .sharedPDF, let url = fileURL,
               let doc = PDFDocument(url: url),
               let firstPage = doc.page(at: 0) {
                let pageImage = firstPage.thumbnail(of: CGSize(width: 400, height: 600), for: .mediaBox)
                ocrText = (try? await recognizeText(in: pageImage)) ?? ""
                thumbPath = saveThumbnail(pageImage, id: id)
            } else if sourceType == .sharedVideo, let url = fileURL {
                thumbPath = await videoThumbnail(from: url, id: id)
            }

            try save(MemoryPayload(
                id: id,
                sourceType: sourceType,
                title: title,
                ocrText: ocrText,
                thumbnailPath: thumbPath,
                sourceURL: fileURL?.absoluteString
            ))
            succeed()
        } catch {
            fail(reason: "\(label) handler: \(error.localizedDescription)")
        }
    }

    // MARK: - Document handler (Word, Excel, Keynote, generic files)

    private func handleDocument(_ provider: NSItemProvider, typeID: String, label: String) async {
        do {
            let raw = try await provider.loadItem(forTypeIdentifier: typeID)
            let fileURL = raw as? URL
            let filename = fileURL?.lastPathComponent ?? label
            let title = filename.isEmpty ? label : filename
            lastAttemptedTitle = title
            var ocrText = ""

            if let url = fileURL, let data = try? Data(contentsOf: url) {
                let candidate = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .isoLatin1)
                if let s = candidate {
                    let printable = s.unicodeScalars.filter { $0.value > 31 && $0.value < 127 }.count
                    if Double(printable) / Double(max(s.count, 1)) > 0.5 {
                        ocrText = String(s.prefix(8000))
                    }
                }
            }
            if ocrText.isEmpty { ocrText = "\(label): \(filename)" }

            let id = UUID()
            try save(MemoryPayload(
                id: id,
                sourceType: .sharedFile,
                title: title,
                ocrText: ocrText,
                thumbnailPath: nil,
                sourceURL: fileURL?.absoluteString
            ))
            succeed()
        } catch {
            fail(reason: "Document handler: \(error.localizedDescription)")
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
        // Timeout after 5 s to avoid stalling the extension
        let session = URLSession(configuration: {
            let c = URLSessionConfiguration.default
            c.timeoutIntervalForRequest = 5
            return c
        }())
        guard let (data, _) = try? await session.data(from: url),
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

    private func videoThumbnail(from url: URL, id: UUID) async -> String? {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 400, height: 400)
        guard let cgImage = try? await gen.image(at: .zero).image else { return nil }
        return saveThumbnail(UIImage(cgImage: cgImage), id: id)
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

    private enum SaveError: Error {
        case noGroupContainer
        case swiftDataError(String)
    }

    private func save(_ payload: MemoryPayload) throws {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.recallthat.app"
        ) else { throw SaveError.noGroupContainer }

        let storeURL = groupURL.appendingPathComponent("recallthat.sqlite")
        let config = ModelConfiguration(url: storeURL)
        do {
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
        } catch {
            throw SaveError.swiftDataError(error.localizedDescription)
        }
    }

    // MARK: - Debug entry

    /// Writes failure info to the shared UserDefaults so the main app can surface it as a list item.
    private func saveDebugEntry(reason: String) {
        let defaults = UserDefaults(suiteName: "group.com.recallthat.app")
        var entries = (defaults?.array(forKey: "shareDebugEntries") as? [[String: String]]) ?? []
        let entry: [String: String] = [
            "id":    UUID().uuidString,
            "ts":    "\(Date().timeIntervalSince1970)",
            "why":   reason,
            "types": lastDetectedTypes.joined(separator: ", "),
            "url":   lastAttemptedURL ?? "",
            "title": lastAttemptedTitle ?? ""
        ]
        entries.insert(entry, at: 0)
        entries = Array(entries.prefix(20))          // keep last 20 failures
        defaults?.set(entries, forKey: "shareDebugEntries")
    }

    // MARK: - State transitions

    private func succeed() {
        UserDefaults(suiteName: "group.com.recallthat.app")?.set(Date().timeIntervalSince1970, forKey: "lastShareSave")
        shareState.phase = .saved
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            extensionContext?.completeRequest(returningItems: nil)
        }
    }

    private func fail(reason: String = "Unknown error") {
        saveDebugEntry(reason: reason)
        // Signal the main app so it picks up the debug entry immediately
        UserDefaults(suiteName: "group.com.recallthat.app")?.set(Date().timeIntervalSince1970, forKey: "lastShareSave")
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
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
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
                    Text("A debug entry was saved in RecallThat.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Dismiss", action: onCancel)
                        .padding(.top, 8)
                }
            }

            Spacer()
        }
    }
}
