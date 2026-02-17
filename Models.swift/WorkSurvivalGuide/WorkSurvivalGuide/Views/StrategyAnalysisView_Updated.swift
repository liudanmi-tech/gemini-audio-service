import SwiftUI

// 更新后的策略分析视图（支持图片显示）
struct StrategyAnalysisView_Updated: View {
    let sessionId: String
    let baseURL: String
    
    @State private var strategyAnalysis: StrategyAnalysisResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedStrategyIndex: Int?
    @State private var highlightsExpanded = false
    @State private var improvementsExpanded = false
    @State private var strategyPopupItem: StrategyItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题区域（根据Figma设计）
            HStack(alignment: .center, spacing: 11.995269775390625) {
                // 图标背景
                ZStack {
                    Circle()
                        .fill(AppColors.headerText.opacity(0.1))
                        .overlay(
                            Circle()
                                .stroke(AppColors.headerText.opacity(0.2), lineWidth: 0.69)
                        )
                        .frame(width: 39.99, height: 39.99)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 19.99))
                        .foregroundColor(AppColors.headerText.opacity(0.8))
                }
                
                // 标题文字区域
                VStack(alignment: .leading, spacing: 1.9938383102416992) {
                    Text("AI ANALYST")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.headerText.opacity(0.6))
                        .tracking(0.5)
                        .textCase(.uppercase)
                    
                    Text("技能分析")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.headerText)
                }
                
                Spacer()
                
                // 命中的技能（右对齐）
                if let analysis = strategyAnalysis, let skills = analysis.appliedSkills, !skills.isEmpty {
                    Text(formatAppliedSkills(skills))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.headerText.opacity(0.7))
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .frame(maxWidth: 120, alignment: .trailing)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 19.99) // 根据Figma: padding left 19.99px
            .padding(.top, 0.69) // 根据Figma: padding top 0.69px
            .padding(.bottom, 0.69) // 根据Figma: padding bottom 0.69px
            .frame(height: 68.98) // 根据Figma: height 68.98px
            .background(Color(hex: "#EEE6D7")) // 根据Figma: #EEE6D7
            
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
                VStack(alignment: .leading, spacing: 0) {
                    // 内容区域（根据Figma设计，场景还原图片在最上方）
                    VStack(alignment: .leading, spacing: 0) {
                        // 场景还原图片（使用第一个visual moment，放在最上方）
                        if let firstVisual = analysis.visual.first {
                            SceneRestoreImageView(
                                visualData: firstVisual,
                                baseURL: baseURL
                            )
                            .padding(.horizontal, 0.69) // 根据Figma: padding horizontal 0.69px
                            .padding(.top, 0) // 对齐标题，不留距离
                        }
                        
                        // 情商亮点和待提升点（最多2行，超过可展开/收起）
                        VStack(alignment: .leading, spacing: 7.9968414306640625) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("情商亮点：")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "#5E7C8B"))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                ExpandableTextBlock(
                                    text: StrategyAnalysisView_Updated.extractHighlights(from: analysis.strategies),
                                    isExpanded: $highlightsExpanded
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("待提升点：")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "#5E7C8B"))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                ExpandableTextBlock(
                                    text: StrategyAnalysisView_Updated.extractImprovements(from: analysis.strategies),
                                    isExpanded: $improvementsExpanded
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading) // 自适应宽度
                        .padding(.leading, 23.99) // 根据Figma: padding left 23.99px
                        .padding(.trailing, 23.99) // 右侧padding保持一致
                        .padding(.top, 24) // 场景还原图片下方间距
                        
                        // 推荐应对策略
                        VStack(alignment: .leading, spacing: 11.99520492553711) { // 根据Figma: gap 11.99px
                            // 策略标题
                            Text("推荐应对策略")
                                .font(.system(size: 12, weight: .bold, design: .rounded)) // Nunito 700, 12px
                                .foregroundColor(AppColors.headerText.opacity(0.5)) // rgba(94, 75, 53, 0.5)
                                .tracking(1.2) // letterSpacing 10% of 12px = 1.2pt
                                .textCase(.uppercase)
                                .frame(height: 15.99) // 根据Figma: height 15.99px
                                .frame(maxWidth: .infinity) // 居中
                            
                            // 策略按钮列表（最多3个，点击弹出锦囊）
                            VStack(spacing: 11.995338439941406) {
                                ForEach(Array(analysis.strategies.prefix(3).enumerated()), id: \.element.id) { index, strategy in
                                    StrategyButtonView(
                                        strategy: strategy,
                                        index: index
                                    ) {
                                        strategyPopupItem = strategy
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading) // 自适应宽度
                        .padding(.leading, 23.99) // 根据Figma: padding left 23.99px
                        .padding(.trailing, 23.99) // 右侧padding保持一致
                        .padding(.top, 24) // 情商亮点下方间距
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading) // 确保填充宽度但不超出父容器
        .background(Color.white) // 根据Figma: #FFFFFF
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(hex: "#E8DCC6"), lineWidth: 0.69)
        )
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        .sheet(item: $strategyPopupItem) { strategy in
            StrategyPouchSheet(strategy: strategy) {
                strategyPopupItem = nil
            }
        }
        .onAppear {
            // 优先使用缓存
            let cacheManager = DetailCacheManager.shared
            
            if let cachedStrategy = cacheManager.getCachedStrategy(sessionId: sessionId) {
                print("✅ [StrategyAnalysisView] 使用缓存的策略分析数据: \(sessionId)")
                strategyAnalysis = cachedStrategy
                isLoading = false
                errorMessage = nil
                return
            }
            
            loadStrategyAnalysis()
        }
    }
    
    private func loadStrategyAnalysis() {
        let cacheManager = DetailCacheManager.shared
        
        // 先检查缓存
        if let cachedStrategy = cacheManager.getCachedStrategy(sessionId: sessionId) {
            print("✅ [StrategyAnalysisView] 使用缓存的策略分析数据: \(sessionId)")
            Task { @MainActor in
                strategyAnalysis = cachedStrategy
                isLoading = false
                errorMessage = nil
            }
            return
        }
        
        // 如果正在加载中，跳过重复请求
        if cacheManager.isLoadingStrategy(for: sessionId) {
            print("⚠️ [StrategyAnalysisView] 策略分析正在加载中，跳过重复请求")
            return
        }
        
        // 延迟一点加载，让详情先显示
        Task {
            defer {
                // 清除加载状态
                cacheManager.setLoadingStrategy(false, for: sessionId)
            }
            
            // 等待 0.3 秒，让详情页面先渲染
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            do {
                isLoading = true
                errorMessage = nil
                
                // 设置加载状态
                cacheManager.setLoadingStrategy(true, for: sessionId)
                
                print("📊 [StrategyAnalysisView] 开始加载策略分析，sessionId: \(sessionId)")
                
                let response = try await NetworkManager.shared.getStrategyAnalysis(sessionId: sessionId)
                
                print("✅ [StrategyAnalysisView] 策略分析加载成功")
                print("  关键时刻数量: \(response.visual.count)")
                print("  策略数量: \(response.strategies.count)")
                
                // 缓存策略分析
                cacheManager.cacheStrategy(response, for: sessionId)
                
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
                    let detail = (error as NSError?)?.userInfo[NSLocalizedDescriptionKey] as? String ?? error.localizedDescription
                    if let nsError = error as NSError? {
                        if nsError.code == -1001 || nsError.code == -1005 || detail.contains("timeout") || detail.lowercased().contains("timed out") || detail.contains("连接中断") {
                            errorMessage = "策略分析加载超时或连接中断，可能仍在生成中，请稍后重试"
                        } else if nsError.code == 400 {
                            errorMessage = detail
                        } else if nsError.code == 404 {
                            errorMessage = detail.isEmpty ? "策略分析不存在，可能正在生成中" : detail
                        } else if !detail.isEmpty && detail != error.localizedDescription {
                            errorMessage = detail
                        } else {
                            errorMessage = "加载失败: \(detail)"
                        }
                    } else {
                        errorMessage = "加载失败: \(detail)"
                    }
                    isLoading = false
                }
            }
        }
    }
    
    // 格式化命中的技能为显示文本（skill_id -> 中文名映射）
    private func formatAppliedSkills(_ skills: [AppliedSkill]) -> String {
        let names: [String: String] = [
            "workplace_jungle": "职场丛林",
            "family_relationship": "家庭关系",
            "education_communication": "教育沟通",
            "brainstorm": "头脑风暴"
        ]
        return skills.map { names[$0.skillId] ?? $0.skillId }.joined(separator: "、")
    }
    
    // 辅助函数：从策略中提取情商亮点（返回全文，由 ExpandableTextBlock 做2行截断）
    static func extractHighlights(from strategies: [StrategyItem]) -> String {
        if let firstStrategy = strategies.first, !firstStrategy.content.isEmpty {
            return firstStrategy.content
        }
        return "能够敏锐察觉对方的情绪变化及时给予安抚。"
    }
    
    // 辅助函数：从策略中提取待提升点
    static func extractImprovements(from strategies: [StrategyItem]) -> String {
        if strategies.count > 1, !strategies[1].content.isEmpty {
            return strategies[1].content
        }
        return "在表达拒绝时可以更加委婉，避免直接冲突。"
    }
}

// 可展开/收起的文本块（最多2行，超过显示展开箭头）
struct ExpandableTextBlock: View {
    let text: String
    @Binding var isExpanded: Bool
    private let lineLimit = 2
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(AppColors.headerText.opacity(0.8))
                .lineSpacing(7.58)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(isExpanded ? nil : lineLimit)
            
            if needsExpandButton {
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "收起" : "展示全文")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: "#5E7C8B"))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: "#5E7C8B"))
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var needsExpandButton: Bool {
        text.count > 60
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

// 策略按钮视图（点击弹出锦囊）
struct StrategyButtonView: View {
    let strategy: StrategyItem
    let index: Int
    var onTap: () -> Void = {}
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // 图标或emoji（如果有）
                if index == 2 {
                    // 第三个按钮有emoji
                    Text("🙈")
                        .font(.system(size: 18))
                } else {
                    Image(systemName: index == 0 ? "heart.fill" : "flame.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "#4A5565"))
                }
                
                Text(strategy.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded)) // Nunito 700, 16px
                    .foregroundColor(Color(hex: "#4A5565")) // 根据Figma: #4A5565
            }
            .frame(maxWidth: .infinity)
            .frame(height: index == 2 ? 61.36 : 57.37) // 根据Figma: 第三个按钮高度不同
            .background(Color(hex: "#F3F4F6")) // 根据Figma: #F3F4F6
            .overlay(
                RoundedRectangle(cornerRadius: 12) // 根据Figma: borderRadius 12px
                    .stroke(Color(hex: "#E5E7EB"), lineWidth: 0.69) // 根据Figma: #E5E7EB, strokeWeight 0.69px
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 策略锦囊弹窗（点击策略卡片后展示策略详情）
struct StrategyPouchSheet: View {
    let strategy: StrategyItem
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏：关闭按钮右对齐
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(AppColors.headerText.opacity(0.5))
                }
                .padding(.trailing, 16)
                .padding(.top, 12)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(strategy.title)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.headerText)
                    
                    Text(strategy.content)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(AppColors.headerText.opacity(0.85))
                        .lineSpacing(8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
        }
        .background(Color(hex: "#FDFBF7"))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#E8DCC6"), lineWidth: 1)
        )
        .cornerRadius(16)
    }
}

// 场景还原图片视图（根据Figma设计）
struct SceneRestoreImageView: View {
    let visualData: VisualData
    let baseURL: String
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // 图片背景
            if let imageURL = visualData.getAccessibleImageURL(baseURL: baseURL) {
                AsyncImage(url: URL(string: imageURL)) { phase in
                    switch phase {
                    case .empty:
                        Color(hex: "#F9FAFB") // 根据Figma: #F9FAFB
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Color(hex: "#F9FAFB")
                    @unknown default:
                        Color(hex: "#F9FAFB")
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fill) // 使用fill以填充整个区域
                .clipped()
            } else {
                Color(hex: "#F9FAFB")
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fill)
            }
            
            // 底部渐变遮罩
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.5),
                    Color.black.opacity(0)
                ]),
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fill)
            
            // 底部文字内容
            VStack(alignment: .leading, spacing: 3.998422622680664) { // 根据Figma: gap 3.99px
                // "场景还原"标签
                Text("场景还原")
                    .font(.system(size: 12, weight: .bold, design: .rounded)) // Nunito 700, 12px
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.31)
                    .background(Color.black.opacity(0.5)) // 根据Figma: rgba(0, 0, 0, 0.5)
                    .cornerRadius(4) // 根据Figma: borderRadius 4px
                
                // 引号文字
                Text("\"\(visualData.context)\"")
                    .font(.system(size: 18, weight: .bold, design: .rounded)) // Nunito 700, 18px
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 0) // 根据Figma: boxShadow
            }
            .padding(.leading, 23.99)
            .padding(.bottom, 24) // 底部内边距
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit) // 保持1:1比例，使用fit确保不超出
        .cornerRadius(24)
    }
}

