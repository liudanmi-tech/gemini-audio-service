//
//  SubscriptionView.swift
//  WorkSurvivalGuide
//
//  Pro 订阅 Paywall
//

import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager: SubscriptionManager = .shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // 关闭按钮
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // 标题区
                        VStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 44))
                                .foregroundColor(Color(hex: "#F59E0B"))

                            Text("Go Pro")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.white)

                            Text("Unlock the full MicLnk experience")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)

                        // 功能对比
                        featureSection

                        // 产品卡片
                        productSection

                        // 恢复购买
                        Button("Restore Purchases") {
                            Task { await manager.restorePurchases() }
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.45))

                        // 法律说明
                        Text("Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Manage in App Store Settings.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.3))
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                }
            }
        }
        .onChange(of: manager.isPro) { newValue in
            if newValue { dismiss() }
        }
    }

    // MARK: - Feature rows

    private var featureSection: some View {
        VStack(spacing: 0) {
            featureRow(icon: "mic.fill",
                       title: "30 recordings / month",
                       subtitle: "Free: 3/month")
            Divider().background(Color.white.opacity(0.1))
            featureRow(icon: "photo.stack.fill",
                       title: "3 scene images per recording",
                       subtitle: "Free: 1 image")
            Divider().background(Color.white.opacity(0.1))
            featureRow(icon: "clock.fill",
                       title: "Unlimited history",
                       subtitle: "Free: 30 days only")
            Divider().background(Color.white.opacity(0.1))
            featureRow(icon: "person.2.fill",
                       title: "Archive up to 10 people",
                       subtitle: "Free: included")
        }
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "#F59E0B"))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color(hex: "#F59E0B"))
                .font(.system(size: 18))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Product section

    @ViewBuilder
    private var productSection: some View {
        if manager.products.isEmpty {
            ProgressView()
                .tint(.white)
                .frame(height: 80)
        } else {
            VStack(spacing: 12) {
                ForEach(manager.products, id: \.id) { product in
                    ProductCard(
                        product: product,
                        isRecommended: product.id == SubscriptionManager.quarterlyProductID,
                        onPurchase: { Task { await manager.purchase(product) } }
                    )
                }
            }
        }

        if let error = manager.purchaseError {
            Text(error)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#FF5733"))
                .multilineTextAlignment(.center)
                .padding(.top, -12)
        }
    }
}

// MARK: - Product Card

private struct ProductCard: View {
    let product: Product
    let isRecommended: Bool
    let onPurchase: () -> Void
    @ObservedObject private var manager: SubscriptionManager = .shared

    var body: some View {
        Button(action: onPurchase) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        if isRecommended {
                            Text("BEST VALUE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color(hex: "#F59E0B"))
                                .clipShape(Capsule())
                        }
                    }

                    Text(product.displayPrice)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(hex: "#F59E0B"))
                }

                Spacer()

                if manager.isLoading {
                    ProgressView().tint(.white).scaleEffect(0.9)
                } else {
                    Text("Subscribe")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#F59E0B"))
                        .clipShape(Capsule())
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isRecommended ? Color(hex: "#F59E0B") : Color.white.opacity(0.2),
                        lineWidth: isRecommended ? 1.5 : 1
                    )
            )
        }
        .disabled(manager.isLoading)
    }
}
