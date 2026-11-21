import Foundation
import StoreKit

@MainActor
public final class SubscriptionManager: ObservableObject {
    public static let shared = SubscriptionManager()
    
    // Configurable Product IDs for App Store Connect
    public enum ProductID: String, CaseIterable {
        case weekly = "com.cleanspace.subscription.weekly"
        case yearly = "com.cleanspace.subscription.yearly"
        case lifetime = "com.cleanspace.purchase.lifetime"
    }
    
    @Published public private(set) var isProUser: Bool = false
    @Published public private(set) var products: [Product] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public var errorMessage: String?
    
    // For local testing & review: unlocks features when enabled
    @Published public var debugUnlockPro: Bool = false {
        didSet {
            updateProStatus()
        }
    }
    
    private init() {
        Task {
            await loadProducts()
            await checkCurrentEntitlements()
        }
    }
    
    public func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let productIDs = ProductID.allCases.map { $0.rawValue }
            let loadedProducts = try await Product.products(for: Set(productIDs))
            self.products = loadedProducts.sorted { $0.price < $1.price }
        } catch {
            self.errorMessage = "Không thể tải sản phẩm: \(error.localizedDescription)"
        }
    }
    
    public func purchase(_ product: Product) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await checkCurrentEntitlements()
                return true
            case .userCancelled:
                return false
            case .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            self.errorMessage = "Giao dịch không thành công: \(error.localizedDescription)"
            return false
        }
    }
    
    public func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        try? await AppStore.sync()
        await checkCurrentEntitlements()
    }
    
    public func checkCurrentEntitlements() async {
        if debugUnlockPro {
            self.isProUser = true
            return
        }
        
        var hasActiveEntitlement = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.revocationDate == nil {
                    hasActiveEntitlement = true
                    break
                }
            }
        }
        self.isProUser = hasActiveEntitlement
    }
    
    private func updateProStatus() {
        if debugUnlockPro {
            self.isProUser = true
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
