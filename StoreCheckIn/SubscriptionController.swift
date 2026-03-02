import Foundation
import StoreKit

@MainActor
final class SubscriptionController: ObservableObject {
    static let monthlyProductID = "com.Store.StoreCheckIn.pro.monthly"

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoading = true
    @Published private(set) var isPurchasing = false
    @Published var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

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
        purchasedProductIDs.contains(Self.monthlyProductID)
    }

    var monthlyProduct: Product? {
        products.first(where: { $0.id == Self.monthlyProductID })
    }

    var monthlyDisplayPrice: String {
        monthlyProduct?.displayPrice ?? "$9.99"
    }

    var planName: String {
        monthlyProduct?.displayName ?? "StoreCheckIn Pro Monthly"
    }

    var statusSummary: String {
        hasActiveSubscription ? "Subscription active" : "Subscription inactive"
    }

    func bootstrap() async {
        isLoading = true
        await requestProducts()
        await refreshEntitlements()
        isLoading = false
    }

    func requestProducts() async {
        do {
            products = try await Product.products(for: [Self.monthlyProductID])
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
        var newProductIDs: Set<String> = []

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.revocationDate == nil else { continue }
            guard !transaction.isUpgraded else { continue }

            newProductIDs.insert(transaction.productID)
        }

        purchasedProductIDs = newProductIDs
    }

    func purchaseMonthlyPlan() async {
        if monthlyProduct == nil {
            await requestProducts()
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
                errorMessage = nil
                purchasedProductIDs.insert(transaction.productID)
                await transaction.finish()
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

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task {
            for await result in Transaction.updates {
                do {
                    let transaction = try checkVerified(result)
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
