import SwiftUI

// 更新后的策略分析视图（支持图片显示）
struct StrategyAnalysisView_Updated: View {
    let sessionId: String
    let baseURL: String
    
    @State private var strategyAnalysis: StrategyAnalysisResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedStrategyIndex: Int?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题（深色背景）
            Text("回放分析与策略")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color.black)
            
            if isLoading {
                // 静默加载，不显示明显的加载提示，只显示一个小的加载指示器
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("策略分析加载中...")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .padding()
            } else if let errorMessage = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button(action: {
                        loadStrategyAnalysis()
                    }) {
                        Text("重试")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .padding()
            } else if let analysis = strategyAnalysis {
                VStack(alignment: .leading, spacing: 16) {
                    // 关键时刻图片轮播
                    VisualMomentCarouselView(
                        visualMoments: analysis.visual,
                        baseURL: baseURL  // 使用传入的 baseURL
                    )
                    
                    // AI策略建议标题
                    Text("AI 策略建议")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    // 策略列表
                    VStack(spacing: 8) {
                        ForEach(Array(analysis.strategies.enumerated()), id: \.element.id) { index, strategy in
                            StrategyCardView(
                                strategy: strategy,
                                isSelected: selectedStrategyIndex == index,
                                action: {
                                    selectedStrategyIndex = selectedStrategyIndex == index ? nil : index
                                }
                            )
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1.38)
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 3, y: 3)
        .onAppear {
            loadStrategyAnalysis()
        }
    }
    
    private func loadStrategyAnalysis() {
        // 延迟一点加载，让详情先显示
        Task {
            // 等待 0.3 秒，让详情页面先渲染
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            do {
                isLoading = true
                errorMessage = nil
                
                print("📊 [StrategyAnalysisView] 开始加载策略分析，sessionId: \(sessionId)")
                
                let response = try await NetworkManager.shared.getStrategyAnalysis(sessionId: sessionId)
                
                print("✅ [StrategyAnalysisView] 策略分析加载成功")
                print("  关键时刻数量: \(response.visual.count)")
                print("  策略数量: \(response.strategies.count)")
                
                for (index, visual) in response.visual.enumerated() {
                    print("  关键时刻 \(index):")
                    print("    imageUrl: \(visual.imageUrl ?? "nil")")
                    print("    imageBase64: \(visual.imageBase64 != nil ? "有数据 (\(visual.imageBase64!.count) 字符)" : "nil")")
                }
                
                await MainActor.run {
                    strategyAnalysis = response
                    isLoading = false
                }
            } catch {
                print("❌ [StrategyAnalysisView] 策略分析加载失败: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("  错误域: \(nsError.domain)")
                    print("  错误码: \(nsError.code)")
                    print("  用户信息: \(nsError.userInfo)")
                }
                
                await MainActor.run {
                    // 生成友好的错误提示
                    if let nsError = error as NSError? {
                        if nsError.code == -1001 || error.localizedDescription.contains("timeout") {
                            errorMessage = "策略分析加载超时，策略分析可能正在生成中，请稍后重试"
                        } else if nsError.code == 400 {
                            errorMessage = "策略分析数据不完整，请稍后重试"
                        } else if nsError.code == 404 {
                            errorMessage = "策略分析不存在，可能正在生成中"
                        } else {
                            errorMessage = "加载失败: \(error.localizedDescription)"
                        }
                    } else {
                        errorMessage = "加载失败: \(error.localizedDescription)"
                    }
                    isLoading = false
                }
            }
        }
    }
}

// 策略卡片视图
struct StrategyCardView: View {
    let strategy: StrategyItem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(strategy.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if isSelected {
                    Text(strategy.content)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 999)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1.38)
            )
            .cornerRadius(999)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
