import Foundation
import StoreKit
import Combine

@MainActor final class StoreKitService: ObservableObject {
    static let shared = StoreKitService()
    static let monthlyID = "com.Sajjad.project.Footballlive.pro.monthly"
    static let annualID = "com.Sajjad.project.Footballlive.pro.annual"
    static let proProductIDs: Set<String> = [monthlyID, annualID]

    enum PurchaseState: Equatable {
        case idle, loadingProducts, purchasing, pending, cancelled, active, failed(String)
    }

    enum RenewalState: Equatable { case none, subscribed, inGracePeriod, inBillingRetry, expired, revoked }

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var message: String?
    @Published private(set) var purchaseState: PurchaseState = .idle
    @Published private(set) var renewalState: RenewalState = .none
    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.refreshEntitlements()
            }
        }
        Task { await load() }
    }
    deinit { updatesTask?.cancel() }

    var isPro: Bool { !purchasedIDs.isDisjoint(with: Self.proProductIDs) }
    func product(id: String) -> Product? { products.first { $0.id == id } }
    func load() async {
        isLoading = true
        purchaseState = .loadingProducts
        do {
            products = try await Product.products(for: Self.proProductIDs)
            await refreshEntitlements()
            message = products.isEmpty ? L10n.text("Subscription products are not configured in App Store Connect.") : nil
            purchaseState = isPro ? .active : .idle
        } catch { message = error.localizedDescription; purchaseState = .failed(error.localizedDescription) }
        isLoading = false
    }
    func purchase(_ product: Product) async {
        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(.verified(let transaction)):
                await transaction.finish(); await refreshEntitlements(); message = L10n.text("Tempo Pro is active."); purchaseState = .active
            case .success(.unverified): message = L10n.text("The purchase could not be verified."); purchaseState = .failed(message!)
            case .pending: message = L10n.text("The purchase is pending approval."); purchaseState = .pending
            case .userCancelled: message = nil; purchaseState = .cancelled
            @unknown default: message = L10n.text("The purchase could not be completed."); purchaseState = .failed(message!)
            }
        } catch { message = error.localizedDescription; purchaseState = .failed(error.localizedDescription) }
    }
    func restore() async {
        isLoading = true
        do { try await AppStore.sync(); await refreshEntitlements(); message = isPro ? L10n.text("Purchases restored.") : L10n.text("No active subscription was found.") }
        catch { message = error.localizedDescription; purchaseState = .failed(error.localizedDescription) }
        isLoading = false
    }
    private func refreshEntitlements() async {
        var ids = Set<String>()
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil else { continue }
            ids.insert(transaction.productID)
        }
        renewalState = .none
        for product in products where Self.proProductIDs.contains(product.id) {
            guard let subscription = product.subscription,
                  let statuses = try? await subscription.status else { continue }
            for status in statuses {
                let transactionID: String? = {
                    guard case .verified(let transaction) = status.transaction,
                          transaction.revocationDate == nil else { return nil }
                    return transaction.productID
                }()
                switch status.state {
                case .subscribed:
                    renewalState = .subscribed
                    if let transactionID { ids.insert(transactionID) }
                case .inGracePeriod:
                    renewalState = .inGracePeriod
                    if let transactionID { ids.insert(transactionID) }
                case .inBillingRetryPeriod:
                    renewalState = .inBillingRetry
                    if let transactionID { ids.insert(transactionID) }
                case .expired: if ids.isEmpty { renewalState = .expired }
                case .revoked: if ids.isEmpty { renewalState = .revoked }
                default: break
                }
            }
        }
        purchasedIDs = ids
        purchaseState = isPro ? .active : .idle
    }
}
