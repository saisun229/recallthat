import Foundation

/// Where a Memory item came from.
/// Only .screenshot is used in MVP. Other cases are reserved for Phase 10+ (Share Extension).
enum MemorySourceType: String, Codable, CaseIterable {
    case screenshot
    case sharedText    = "sharedText"
    case sharedURL     = "sharedURL"
    case sharedImage   = "sharedImage"
    case sharedPDF     = "sharedPDF"
    case sharedVideo   = "sharedVideo"
    case sharedAudio   = "sharedAudio"
    case sharedFile    = "sharedFile"   // generic doc, spreadsheet, presentation
}
