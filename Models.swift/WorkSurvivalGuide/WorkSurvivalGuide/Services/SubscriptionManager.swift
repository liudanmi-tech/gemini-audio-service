//
//  SubscriptionManager.swift
//  WorkSurvivalGuide
//
//  StoreKit 2 订阅管理
//  负责：加载产品、发起购买、监听事务、与后端验证、缓存状态
//

import StoreKit
import Foundation

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // App Store 产品 ID（与后端 PRODUCT_TIER_MAP 保持一致）
    static let monthlyProductID   = "com.miclnk.pro.monthly"
    static let quarterlyProductID = "com.miclnk.pro.quarterly"
    static let annualProductID    = "com.miclnk.pro.annual"
    static let allProductIDs: Set<String> = [monthlyProductID, quarterlyProductID, annualProductID]

    @Published var products: [Product] = []
    @Published var isPro: Bool = false
    @Published var isLoading: Bool = false
    @Published var purchaseError: String? = nil
    @Published var monthlyLimit: Int = 3
    @Published var usedCount: Int = 0

    private var transactionListenerTask: Task<Void, Error>?

    private init() {
        // 从 UserDefaults 恢复缓存状态（支持离线）
        if let tier = UserDefaults.standard.string(forKey: "sub_tier") {
            isPro = tier == "pro"
        }
        let cachedLimit = UserDefaults.standard.integer(forKey: "sub_monthly_limit")
        monthlyLimit = cachedLimit > 0 ? cachedLimit : 3

        // 后台监听 StoreKit 事务更新
        transactionListenerTask = listenForTransactions()

        Task {
            await loadProducts()
            await refreshFromBackend()
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - 加载 App Store 产品列表

    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: Self.allProductIDs)
            self.products = storeProducts.sorted {
                let order: [String: Int] = [
                    Self.monthlyProductID: 0,
                    Self.quarterlyProductID: 1,
                    Self.annualProductID: 2
                ]
                return (order[$0.id] ?? 99) < (order[$1.id] ?? 99)
            }
            print("[SubscriptionManager] 产品加载成功: \(self.products.map(\.id))")
        } catch {
            print("[SubscriptionManager] 产品加载失败: \(error)")
        }
    }

    // MARK: - 购买

    func purchase(_ product: Product) async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await sendToBackend(originalTransactionId: String(transaction.originalID), productId: transaction.productID)
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                print("[SubscriptionManager] 购买待处理（Ask to Buy）")
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
            print("[SubscriptionManager] 购买失败: \(error)")
        }
    }

    // MARK: - 恢复购买

    func restorePurchases() async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        // 先强制与 App Store 同步（沙盒测试必要）
        try? await AppStore.sync()

        var didRestore = false
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                await sendToBackend(originalTransactionId: String(transaction.originalID), productId: transaction.productID)
                await transaction.finish()
                didRestore = true
            }
        }
        if !didRestore {
            purchaseError = "No active subscriptions found."
        }
    }

    // MARK: - 从后端刷新订阅状态

    func refreshFromBackend() async {
        guard NetworkManager.shared.hasValidToken() else { return }
        do {
            let status = try await NetworkManager.shared.getSubscriptionStatus()
            isPro = status.tier == "pro"
            monthlyLimit = status.monthlyLimit
            usedCount = status.monthlyRecordingCount
            saveToCache(tier: status.tier, limit: status.monthlyLimit)
        } catch {
            print("[SubscriptionManager] 刷新订阅状态失败: \(error)")
        }
    }

    var remainingRecordings: Int { max(0, monthlyLimit - usedCount) }

    // MARK: - Private

    private nonisolated func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if let transaction = try? self.checkVerified(result) {
                    await self.sendToBackend(originalTransactionId: String(transaction.originalID), productId: transaction.productID)
                    await transaction.finish()
                }
            }
        }
    }

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let value): return value
        }
    }

    private func sendToBackend(originalTransactionId: String, productId: String = "") async {
        do {
            try await NetworkManager.shared.verifyAppleTransaction(
                originalTransactionId: originalTransactionId,
                productId: productId
            )
            await refreshFromBackend()
            print("[SubscriptionManager] ✅ 后端验证成功 isPro=\(isPro)")
        } catch {
            print("[SubscriptionManager] 后端验证失败: \(error)")
        }
    }

    private func saveToCache(tier: String, limit: Int) {
        UserDefaults.standard.set(tier, forKey: "sub_tier")
        UserDefaults.standard.set(limit, forKey: "sub_monthly_limit")
    }
}
