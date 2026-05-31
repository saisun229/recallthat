import Foundation

/// Where a Memory item came from.
/// Only .screenshot is used in MVP. Other cases are reserved for Phase 10+ (Share Extension).
enum MemorySourceType: String, Codable, CaseIterable {
    case screenshot
    case sharedText    // Phase 10+
    case sharedURL     // Phase 10+
    case sharedImage   // Phase 10+
}
