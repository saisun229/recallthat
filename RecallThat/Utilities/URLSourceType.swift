import SwiftUI

enum URLSourceType {
    case youtube
    case instagram
    case facebook
    case twitter
    case tiktok
    case reddit
    case other(domain: String)

    static func detect(from urlString: String?) -> URLSourceType {
        guard let urlString, !urlString.isEmpty,
              let host = URL(string: urlString)?.host?.lowercased() else {
            return .other(domain: "Link")
        }
        if host.contains("youtube") || host.contains("youtu.be") { return .youtube }
        if host.contains("instagram")                              { return .instagram }
        if host.contains("facebook") || host.contains("fb.com")   { return .facebook }
        if host.contains("twitter") || host.contains("x.com")     { return .twitter }
        if host.contains("tiktok")                                 { return .tiktok }
        if host.contains("reddit")                                 { return .reddit }
        let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return .other(domain: domain)
    }

    var displayName: String {
        switch self {
        case .youtube:           return "YouTube"
        case .instagram:         return "Instagram"
        case .facebook:          return "Facebook"
        case .twitter:           return "X"
        case .tiktok:            return "TikTok"
        case .reddit:            return "Reddit"
        case .other(let domain): return domain
        }
    }

    var systemIcon: String {
        switch self {
        case .youtube:   return "play.rectangle.fill"
        case .instagram: return "camera.fill"
        case .facebook:  return "person.2.fill"
        case .twitter:   return "at"
        case .tiktok:    return "music.note"
        case .reddit:    return "bubble.left.and.bubble.right.fill"
        case .other:     return "safari.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .youtube:   return Color(red: 1.0, green: 0.0,  blue: 0.0)
        case .instagram: return Color(red: 0.9, green: 0.2,  blue: 0.6)
        case .facebook:  return Color(red: 0.23, green: 0.35, blue: 0.6)
        case .twitter:   return Color.primary
        case .tiktok:    return Color.primary
        case .reddit:    return Color(red: 1.0, green: 0.34, blue: 0.13)
        case .other:     return Color.blue
        }
    }

    var openLabel: String {
        switch self {
        case .youtube:           return "Watch on YouTube"
        case .instagram:         return "Open in Instagram"
        case .facebook:          return "Open in Facebook"
        case .twitter:           return "Open in X"
        case .tiktok:            return "Open in TikTok"
        case .reddit:            return "Open in Reddit"
        case .other(let domain): return "Open in \(domain)"
        }
    }
}
