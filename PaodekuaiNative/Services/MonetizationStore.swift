import Foundation
import Combine
import StoreKit

@MainActor
final class MonetizationStore: ObservableObject {
    static let removeAdsProductID = "com.paodekuai.native.removeads.lifetime"
    private static let premiumKey = "paodekuai.native.premium"
    private static let handCounterKey = "paodekuai.native.hands_since_ad"

    @Published private(set) var isPremium: Bool
    @Published private(set) var handsSinceAd: Int
    @Published var showAdBreak = false
    @Published var purchaseInProgress = false
    @Published var purchaseErrorMessage: String?
    
    private var updateListenerTask: Task<Void, Never>? = nil

    init() {
        isPremium = UserDefaults.standard.bool(forKey: Self.premiumKey)
        handsSinceAd = UserDefaults.standard.integer(forKey: Self.handCounterKey)
        
        updateListenerTask = Task { @MainActor [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                if transaction.productID == MonetizationStore.removeAdsProductID {
                    self?.unlockPremiumLocally()
                }
                await transaction.finish()
            }
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }

    var handsLeftUntilAd: Int {
        max(0, 10 - handsSinceAd)
    }

    func recordCompletedHand() {
        guard !isPremium else { return }
        handsSinceAd += 1
        if handsSinceAd >= 10 {
            handsSinceAd = 0
            showAdBreak = true
        }
        persist()
    }

    func finishAdBreak() {
        showAdBreak = false
    }

    func unlockPremiumLocally() {
        isPremium = true
        showAdBreak = false
        persist()
    }

    func purchaseRemoveAds() async {
        purchaseErrorMessage = nil
        purchaseInProgress = true
        defer { purchaseInProgress = false }

        do {
            let products = try await Product.products(for: [Self.removeAdsProductID])
            guard let product = products.first else {
                purchaseErrorMessage = L10n.text("purchase_error_product_not_found")
                return
            }

            let result = try await product.purchase()
            switch result {
            case .success(let verificationResult):
                switch verificationResult {
                case .verified(let transaction):
                    unlockPremiumLocally()
                    await transaction.finish()
                case .unverified:
                    purchaseErrorMessage = L10n.text("purchase_error_unverified")
                }
            case .pending:
                purchaseErrorMessage = L10n.text("purchase_pending")
            case .userCancelled:
                break
            @unknown default:
                purchaseErrorMessage = L10n.text("purchase_error_unknown")
            }
        } catch {
            purchaseErrorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        purchaseErrorMessage = nil
        purchaseInProgress = true
        defer { purchaseInProgress = false }

        var unlocked = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.removeAdsProductID {
                unlocked = true
                break
            }
        }
        if unlocked {
            unlockPremiumLocally()
        } else {
            purchaseErrorMessage = L10n.text("restore_nothing")
        }
    }

    private func persist() {
        UserDefaults.standard.set(isPremium, forKey: Self.premiumKey)
        UserDefaults.standard.set(handsSinceAd, forKey: Self.handCounterKey)
    }
}
