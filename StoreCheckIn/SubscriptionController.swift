import Foundation
import StoreKit

@MainActor
final class SubscriptionController: ObservableObject {
    static let monthlyProductID = "com.Store.StoreCheckIn.pro.monthly.v2"
    static let legacyMonthlyProductIDs = ["com.Store.StoreCheckIn.pro.monthly"]
    static let supportedMonthlyProductIDs = [monthlyProductID] + legacyMonthlyProductIDs
    private static let entitlementPropagationGraceWindow: TimeInterval = 8
    private static let entitlementRetryDelayNanoseconds: UInt64 = 1_000_000_000

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoading = true
    @Published private(set) var isPurchasing = false
    @Published var errorMessage: String?

    private var updatesTask: Task<Void, Never>?
    private var lastKnownPurchaseDate: Date?

    init() {
        updatesTask = observeTransactionUpdates()

        Task {
            await bootstrap()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var hasActiveSubscription: Bool {
        !purchasedProductIDs.isDisjoint(with: Set(Self.supportedMonthlyProductIDs))
    }

    var monthlyProduct: Product? {
        if let preferredProduct = products.first(where: { $0.id == Self.monthlyProductID }) {
            return preferredProduct
        }

        return products.first(where: { Self.legacyMonthlyProductIDs.contains($0.id) })
    }

    var monthlyDisplayPrice: String {
        monthlyProduct?.displayPrice ?? "$9.99"
    }

    var planName: String {
        monthlyProduct?.displayName ?? "StoreCheckIn Pro Monthly"
    }

    var statusSummary: String {
        return hasActiveSubscription ? "Subscription active" : "Subscription inactive"
    }

    func bootstrap() async {
        isLoading = true
        await requestProducts()
        await refreshEntitlements()
        isLoading = false
    }

    func requestProducts() async {
        do {
            products = try await Product.products(for: Self.supportedMonthlyProductIDs)
            if products.isEmpty {
                errorMessage = "Monthly subscription product is not available yet."
            } else {
                errorMessage = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        let newProductIDs = await fetchActiveEntitlements()

        if shouldPreserveCurrentEntitlements(for: newProductIDs) {
            Task {
                try? await Task.sleep(nanoseconds: Self.entitlementRetryDelayNanoseconds)
                await refreshEntitlements()
            }
            return
        }

        purchasedProductIDs = mergedProductIDs(with: newProductIDs)
    }

    func purchaseMonthlyPlan() async {
        if monthlyProduct == nil {
            await requestProducts()
        }

        await finishUnfinishedSupportedTransactions()
        await refreshEntitlements()

        if hasActiveSubscription {
            errorMessage = nil
            return
        }

        guard let product = monthlyProduct else {
            errorMessage = "Create the monthly product in App Store Connect using \(Self.monthlyProductID)."
            return
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                if isActiveEntitlement(transaction) {
                    errorMessage = nil
                    applyVerifiedEntitlement(from: transaction)
                }
                await transaction.finish()
                await refreshEntitlements()
                if !hasActiveSubscription {
                    errorMessage = "Subscription did not activate. In Sandbox, clear purchase history or sign out and back in to the Sandbox Apple Account, then try again."
                }
            case .pending:
                errorMessage = "Purchase is pending approval."
            case .userCancelled:
                errorMessage = nil
            @unknown default:
                errorMessage = "Purchase could not be completed."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !hasActiveSubscription {
                errorMessage = "No active subscription was found to restore."
            } else {
                errorMessage = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchActiveEntitlements() async -> Set<String> {
        var newProductIDs: Set<String> = []

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard Self.supportedMonthlyProductIDs.contains(transaction.productID) else { continue }
            guard isActiveEntitlement(transaction) else { continue }

            newProductIDs.insert(transaction.productID)
        }

        return mergedProductIDs(with: newProductIDs)
    }

    private func finishUnfinishedSupportedTransactions() async {
        for await result in Transaction.unfinished {
            switch result {
            case .verified(let transaction):
                guard Self.supportedMonthlyProductIDs.contains(transaction.productID) else { continue }
                await transaction.finish()
            case .unverified:
                continue
            }
        }
    }

    private func mergedProductIDs(with productIDs: Set<String>) -> Set<String> {
        productIDs
    }

    private func applyVerifiedEntitlement(from transaction: Transaction) {
        guard Self.supportedMonthlyProductIDs.contains(transaction.productID) else { return }
        guard isActiveEntitlement(transaction) else { return }
        lastKnownPurchaseDate = .now
        purchasedProductIDs.insert(transaction.productID)
    }

    private func shouldPreserveCurrentEntitlements(for newProductIDs: Set<String>) -> Bool {
        guard newProductIDs.isEmpty else { return false }
        guard !purchasedProductIDs.isDisjoint(with: Set(Self.supportedMonthlyProductIDs)) else { return false }
        guard let lastKnownPurchaseDate else { return false }

        return Date.now.timeIntervalSince(lastKnownPurchaseDate) < Self.entitlementPropagationGraceWindow
    }

    private func isActiveEntitlement(_ transaction: Transaction) -> Bool {
        guard transaction.revocationDate == nil else { return false }
        guard !transaction.isUpgraded else { return false }

        if let expirationDate = transaction.expirationDate {
            return expirationDate > .now
        }

        return true
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task {
            for await result in Transaction.updates {
                do {
                    let transaction = try checkVerified(result)
                    applyVerifiedEntitlement(from: transaction)
                    await transaction.finish()
                    await refreshEntitlements()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let signedType):
            return signedType
        case .unverified:
            throw SubscriptionError.failedVerification
        }
    }
}

private enum SubscriptionError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "The App Store transaction could not be verified."
        }
    }
}
