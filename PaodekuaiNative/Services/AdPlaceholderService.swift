import Foundation

enum AdPlacement: String {
    case gameOverBanner
    case handEndInterstitial
}

/// Placeholder for future ad SDK integration.
/// Current build is fully offline and does not request ad network.
final class AdPlaceholderService {
    func canShow(_ placement: AdPlacement) -> Bool {
        false
    }

    func markEvent(_ placement: AdPlacement) {
        _ = placement
    }
}
