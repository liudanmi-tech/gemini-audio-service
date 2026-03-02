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
                
                // 用新风格重新生成（始终可见，便于更换图片风格）
                if strategyAnalysis != nil {
                    Button(action: { loadStrategyAnalysis(forceRegenerate: true) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "photo.artframe")
                            Text("用新风格重新生成")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(AppColors.headerText.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                
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
            .background(Color.white.opacity(0.1))
            
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
                    // 优先使用 skill_cards 多卡片滑动，无则尝试从 applied_skills+visual+strategies 构造兜底卡片
                    let cardsToShow: [SkillCard] = {
                        if let cards = analysis.skillCards, !cards.isEmpty { return cards }
                        // skill_cards 解码失败时的兜底：从 visual+strategies+appliedSkills 构造
                        if let skills = analysis.appliedSkills, skills.count >= 1,
                           !analysis.visual.isEmpty || !analysis.strategies.isEmpty {
                            let content = SkillCardContent(
                                sighCount: nil, hahaCount: nil, moodState: nil, moodEmoji: nil, charCount: nil,
                                visual: analysis.visual.isEmpty ? nil : analysis.visual,
                                strategies: analysis.strategies.isEmpty ? nil : analysis.strategies,
                                defenseEnergyPct: nil, dominantDefense: nil, statusAssessment: nil,
                                cognitiveTriad: nil, insight: nil, strategy: nil, crisisAlert: nil
                            )
                            return skills.map { s in
                                let name = (["workplace_jungle": "职场丛林", "family_relationship": "家庭关系", "emotion_recognition": "情绪识别", "depression_prevention": "防抑郁监控"])[s.skillId] ?? s.skillId
                                let ct = s.skillId == "emotion_recognition" ? "emotion" : "strategy"
                                return SkillCard(skillId: s.skillId, skillName: name, contentType: ct, content: content)
                            }
                        }
                        return []
                    }()
                    if !cardsToShow.isEmpty {
                        // 场景图片轮播（置于技能卡片之上）
                        let sceneImgs = analysis.sceneImages ?? []
                        SceneRestoreImageCarouselView(sceneImages: sceneImgs, baseURL: baseURL)
                            .padding(.horizontal, 0.69)
                            .padding(.top, 0)
                        SkillCardsTabView(cards: cardsToShow, baseURL: baseURL)
                            .padding(.horizontal, 0.69)
                            .padding(.top, 0)
                    } else {
                        // 兼容旧数据：场景还原图片 + 情商亮点等
                        VStack(alignment: .leading, spacing: 0) {
                            // 旧数据无 skill_cards 时，提供重新生成入口
                            if analysis.skillCards == nil || (analysis.skillCards?.isEmpty == true), !analysis.visual.isEmpty {
                                Button(action: { loadStrategyAnalysis(forceRegenerate: true) }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.clockwise")
                                        Text("重新生成（含情绪分析）")
                                    }
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(hex: "#5E7C8B"))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                            let legacySceneImgs = analysis.sceneImages ?? []
                            SceneRestoreImageCarouselView(sceneImages: legacySceneImgs, baseURL: baseURL)
                                .padding(.horizontal, 0.69)
                                .padding(.top, 0)
                            
                            LegacyStrategyContent(
                                analysis: analysis,
                                highlightsExpanded: $highlightsExpanded,
                                improvementsExpanded: $improvementsExpanded,
                                strategyPopupItem: $strategyPopupItem
                            )
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading) // 确保填充宽度但不超出父容器
        .background(
            Group {
                if let analysis = strategyAnalysis,
                   let firstScene = analysis.sceneImages?.first,
                   let imageUrl = firstScene.getAccessibleImageURL(baseURL: baseURL) {
                    FrostedGlassDiffractionBackground(imageUrl: imageUrl)
                } else {
                    AppColors.cardBackground
                }
            }
        )
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
    
    private func loadStrategyAnalysis(forceRegenerate: Bool = false) {
        let cacheManager = DetailCacheManager.shared
        
        // 强制重新生成时清除缓存
        if forceRegenerate {
            cacheManager.clearCache(for: sessionId)
        }
        
        // 非强制时先检查缓存
        if !forceRegenerate, let cachedStrategy = cacheManager.getCachedStrategy(sessionId: sessionId) {
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
            
            isLoading = true
            errorMessage = nil
            cacheManager.setLoadingStrategy(true, for: sessionId)
            
            // 方案 A 短轮询：失败时自动重试，避免单次长请求超时导致二次等待
            let maxRetries = 3
            var lastError: Error?
            for attempt in 1...maxRetries {
                do {
                    print("📊 [StrategyAnalysisView] 加载策略分析 sessionId=\(sessionId) 第\(attempt)/\(maxRetries)次")
                    let response = try await NetworkManager.shared.getStrategyAnalysis(sessionId: sessionId, forceRegenerate: forceRegenerate)
                    
                    print("✅ [StrategyAnalysisView] 策略分析加载成功")
                    print("  关键时刻数量: \(response.visual.count)")
                    print("  策略数量: \(response.strategies.count)")
                    print("  场景图片数量: \(response.sceneImages?.count ?? -1) (nil=\(response.sceneImages == nil))")
                    
                    cacheManager.cacheStrategy(response, for: sessionId)
                    
                    await MainActor.run {
                        strategyAnalysis = response
                        isLoading = false
                        if let cards = response.skillCards, !cards.isEmpty {
                            print("✅ [StrategyAnalysisView] 使用 skill_cards 展示，共 \(cards.count) 张")
                        } else {
                            print("⚠️ [StrategyAnalysisView] skillCards 为空或 nil，回退到旧版 visual+strategies")
                        }
                    }
                    return
                } catch {
                    lastError = error
                    print("❌ [StrategyAnalysisView] 第\(attempt)次加载失败: \(error.localizedDescription)")
                    if attempt < maxRetries {
                        let delay: UInt64 = 5
                        print("🔄 [StrategyAnalysisView] \(delay)秒后重试...")
                        try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
                    }
                }
            }
            
            // 全部重试失败
            await MainActor.run {
                let detail = (lastError as NSError?)?.userInfo[NSLocalizedDescriptionKey] as? String ?? lastError?.localizedDescription ?? "未知错误"
                if let nsError = lastError as NSError? {
                    if nsError.code == -1001 || nsError.code == -1005 || detail.contains("timeout") || detail.lowercased().contains("timed out") || detail.contains("连接中断") {
                        errorMessage = "策略分析加载超时或连接中断，可能仍在生成中，请点击重试"
                    } else if nsError.code == 400 {
                        errorMessage = detail
                    } else if nsError.code == 404 {
                        errorMessage = detail.isEmpty ? "策略分析不存在，可能正在生成中" : detail
                    } else if !detail.isEmpty && detail != (lastError?.localizedDescription ?? "") {
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
    
    private func formatAppliedSkills(_ skills: [AppliedSkill]) -> String {
        let names: [String: String] = [
            "workplace_jungle": "职场丛林",
            "workplace_role": "角色方位",
            "workplace_scenario": "场景情境",
            "workplace_psychology": "心理风格",
            "workplace_career": "职业阶段",
            "workplace_capability": "能力维度",
            "family_relationship": "家庭关系",
            "education_communication": "教育沟通",
            "brainstorm": "头脑风暴",
            "emotion_recognition": "情绪识别",
            "depression_prevention": "防抑郁监控"
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

// 技能卡片视图（场景 Tab + 策略图置顶 + 维度手风琴）
struct SkillCardsTabView: View {
    let cards: [SkillCard]
    let baseURL: String
    @State private var selectedScene: String = ""
    @State private var expandedCardIds: Set<String> = []
    
    private var sceneOrder: [String] { ["职场", "家庭", "个人"] }
    
    private var scenes: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for s in sceneOrder {
            if cards.contains(where: { $0.sceneCategory == s }) && !seen.contains(s) {
                seen.insert(s)
                result.append(s)
            }
        }
        return result
    }
    
    private var currentSceneCards: [SkillCard] {
        cards.filter { $0.sceneCategory == selectedScene }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if cards.isEmpty {
                Text("暂无技能分析")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                // 顶部：场景分类 Tab（职场/家庭/个人），始终显示命中的类目
                if !scenes.isEmpty {
                    SceneTabBar(scenes: scenes, selectedScene: $selectedScene)
                }
                
                // 维度手风琴面板
                VStack(spacing: 0) {
                    ForEach(Array(currentSceneCards.enumerated()), id: \.element.id) { index, card in
                        SkillAccordionPanel(
                            card: card,
                            isExpanded: expandedCardIds.contains(card.id),
                            baseURL: baseURL
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                if expandedCardIds.contains(card.id) {
                                    expandedCardIds.remove(card.id)
                                } else {
                                    expandedCardIds.insert(card.id)
                                }
                            }
                        }
                        
                        if index < currentSceneCards.count - 1 {
                            Divider()
                                .background(Color(hex: "#E8DCC6").opacity(0.5))
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .onAppear {
            if selectedScene.isEmpty, let first = scenes.first {
                selectedScene = first
            }
            if expandedCardIds.isEmpty, let firstCard = currentSceneCards.first {
                expandedCardIds = [firstCard.id]
            }
        }
        .onChange(of: selectedScene) { _ in
            if let firstCard = currentSceneCards.first {
                expandedCardIds = [firstCard.id]
            } else {
                expandedCardIds = []
            }
        }
    }
}

// 场景分类 Tab 栏
private struct SceneTabBar: View {
    let scenes: [String]
    @Binding var selectedScene: String
    
    private func iconFor(_ scene: String) -> String {
        switch scene {
        case "职场": return "briefcase.fill"
        case "家庭": return "house.fill"
        case "个人": return "person.fill"
        default: return "circle.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(scenes, id: \.self) { scene in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedScene = scene }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: iconFor(scene))
                            .font(.system(size: 12))
                        Text(scene)
                            .font(.system(size: 14, weight: selectedScene == scene ? .bold : .medium, design: .rounded))
                    }
                    .foregroundColor(selectedScene == scene ? .white : AppColors.headerText.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedScene == scene ? Color(hex: "#5E7C8B") : Color.clear)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.06))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// 手风琴面板（可折叠的单个技能）
private struct SkillAccordionPanel: View {
    let card: SkillCard
    let isExpanded: Bool
    let baseURL: String
    let onToggle: () -> Void
    
    private var dimensionIcon: String {
        if let dim = card.dimension, let d = WorkplaceDimension.from(key: dim) {
            return d.icon
        }
        switch card.contentType {
        case "emotion": return "face.smiling"
        case "mental_health": return "heart.text.square"
        default: return "lightbulb.fill"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 面板标题栏（点击展开/折叠）
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    Image(systemName: dimensionIcon)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#5E7C8B"))
                        .frame(width: 20)
                    
                    Text(card.accordionTitle)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.headerText)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.headerText.opacity(0.4))
                }
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            
            // 展开内容
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    if card.contentType == "emotion", let content = card.content?.emotionContent {
                        EmotionCardView(content: content)
                    } else if card.contentType == "mental_health", let content = card.content?.mentalHealthContent {
                        MentalHealthCardView(content: content)
                    } else if let strategies = card.content?.strategies, !strategies.isEmpty {
                        // 策略型卡片只展示策略列表（visual 已在顶部轮播展示）
                        SkillStrategiesOnlyView(strategies: strategies)
                    } else {
                        Text("暂无内容")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// 仅策略列表（不含 visual，用于手风琴面板内部）
private struct SkillStrategiesOnlyView: View {
    let strategies: [StrategyItem]
    @State private var strategyPopupItem: StrategyItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("推荐应对策略")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.headerText.opacity(0.5))
                .textCase(.uppercase)
            ForEach(Array(strategies.prefix(4).enumerated()), id: \.element.id) { index, strategy in
                StrategyButtonView(strategy: strategy, index: index) {
                    strategyPopupItem = strategy
                }
            }
        }
        .padding(.bottom, 12)
        .sheet(item: $strategyPopupItem) { strategy in
            StrategyPouchSheet(strategy: strategy) {
                strategyPopupItem = nil
            }
        }
    }
}

// 单张技能卡片（策略型 / 情绪型）- 用于策略分析页
struct StrategySkillCardView: View {
    let card: SkillCard
    let baseURL: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if card.contentType == "emotion", let content = card.content?.emotionContent {
                EmotionCardView(content: content)
            } else if card.contentType == "mental_health", let content = card.content?.mentalHealthContent {
                MentalHealthCardView(content: content)
            } else if let content = card.content?.strategyContent {
                StrategyCardContent(content: content, baseURL: baseURL)
            } else {
                Text("暂无内容")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

// 情绪卡片 UI（emoji + 统计数据）
struct EmotionCardView: View {
    let content: SkillCardEmotionContent
    
    var body: some View {
        VStack(spacing: 16) {
            Text(content.moodEmoji)
                .font(.system(size: 64))
            Text(content.moodState)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.headerText)
            HStack(spacing: 24) {
                StatItem(label: "叹气", value: "\(content.sighCount)")
                StatItem(label: "哈哈", value: "\(content.hahaCount)")
                StatItem(label: "字数", value: "\(content.charCount)")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// 防抑郁监控卡片 UI
struct MentalHealthCardView: View {
    let content: SkillCardMentalHealthContent
    
    private func triadColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "red": return Color.red
        case "yellow": return Color.yellow
        default: return Color.green
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if content.crisisAlert {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("请重视当前状态，必要时寻求专业帮助")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.red)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.15))
                .cornerRadius(8)
                Text("危机热线：4001619995")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.red)
            }
            
            // 防御能耗仪表盘
            VStack(alignment: .leading, spacing: 8) {
                Text("防御能耗")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.headerText.opacity(0.6))
                    .textCase(.uppercase)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(content.defenseEnergyPct > 70 ? Color.red : (content.defenseEnergyPct > 40 ? Color.yellow : Color.green))
                            .frame(width: max(0, geo.size.width * CGFloat(min(100, max(0, content.defenseEnergyPct))) / 100))
                    }
                }
                .frame(height: 8)
                Text("\(content.defenseEnergyPct)% · \(content.dominantDefense)")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(AppColors.headerText.opacity(0.8))
                if !content.statusAssessment.isEmpty {
                    Text(content.statusAssessment)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(AppColors.headerText.opacity(0.6))
                }
            }
            
            // 认知三联征
            if let triad = content.cognitiveTriad {
                VStack(alignment: .leading, spacing: 8) {
                    Text("认知趋势")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.headerText.opacity(0.6))
                        .textCase(.uppercase)
                    HStack(alignment: .top, spacing: 16) {
                        if let s = triad.selfStatus {
                            VStack(alignment: .leading, spacing: 4) {
                                Circle().fill(triadColor(s.status)).frame(width: 8, height: 8)
                                Text("自我").font(.system(size: 11, design: .rounded)).foregroundColor(AppColors.headerText.opacity(0.6))
                                Text(s.reason).font(.system(size: 12, design: .rounded)).foregroundColor(AppColors.headerText.opacity(0.8))
                            }
                        }
                        if let w = triad.world {
                            VStack(alignment: .leading, spacing: 4) {
                                Circle().fill(triadColor(w.status)).frame(width: 8, height: 8)
                                Text("世界").font(.system(size: 11, design: .rounded)).foregroundColor(AppColors.headerText.opacity(0.6))
                                Text(w.reason).font(.system(size: 12, design: .rounded)).foregroundColor(AppColors.headerText.opacity(0.8))
                            }
                        }
                        if let f = triad.future {
                            VStack(alignment: .leading, spacing: 4) {
                                Circle().fill(triadColor(f.status)).frame(width: 8, height: 8)
                                Text("未来").font(.system(size: 11, design: .rounded)).foregroundColor(AppColors.headerText.opacity(0.6))
                                Text(f.reason).font(.system(size: 12, design: .rounded)).foregroundColor(AppColors.headerText.opacity(0.8))
                            }
                        }
                    }
                }
            }
            
            if !content.insight.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("军师洞察")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.headerText.opacity(0.6))
                        .textCase(.uppercase)
                    Text(content.insight)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(AppColors.headerText)
                        .lineSpacing(4)
                }
            }
            
            if !content.strategy.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("破局策略")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.headerText.opacity(0.6))
                        .textCase(.uppercase)
                    Text(content.strategy)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(AppColors.headerText)
                        .lineSpacing(4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
    }
}

struct StatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#5E7C8B"))
            Text(label)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(AppColors.headerText.opacity(0.6))
        }
    }
}

// 策略卡片内容（visual + strategies）
struct StrategyCardContent: View {
    let content: SkillCardStrategyContent
    let baseURL: String
    @State private var strategyPopupItem: StrategyItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 仅当 visual 中有实际图片时显示（skill_cards 新架构下 visual 不含图片）
            let visualWithImages = content.visual?.filter { $0.imageUrl != nil || $0.imageBase64 != nil } ?? []
            if !visualWithImages.isEmpty {
                // 旧架构兼容：若 visual 含图片则仍可展示（当前新架构下此分支不会触发）
                let _ = visualWithImages  // suppress unused warning
            }
            if let strategies = content.strategies, !strategies.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("推荐应对策略")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.headerText.opacity(0.5))
                        .textCase(.uppercase)
                    ForEach(Array(strategies.prefix(3).enumerated()), id: \.element.id) { index, strategy in
                        StrategyButtonView(strategy: strategy, index: index) {
                            strategyPopupItem = strategy
                        }
                    }
                }
                .sheet(item: $strategyPopupItem) { strategy in
                    StrategyPouchSheet(strategy: strategy) {
                        strategyPopupItem = nil
                    }
                }
            }
        }
    }
}

// 兼容旧数据的策略内容区域
struct LegacyStrategyContent: View {
    let analysis: StrategyAnalysisResponse
    @Binding var highlightsExpanded: Bool
    @Binding var improvementsExpanded: Bool
    @Binding var strategyPopupItem: StrategyItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
            .frame(maxWidth: .infinity, alignment: .topLeading)
            VStack(alignment: .leading, spacing: 11.99520492553711) {
                Text("推荐应对策略")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.headerText.opacity(0.5))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .frame(height: 15.99)
                    .frame(maxWidth: .infinity)
                VStack(spacing: 11.995338439941406) {
                    ForEach(Array(analysis.strategies.prefix(3).enumerated()), id: \.element.id) { index, strategy in
                        StrategyButtonView(strategy: strategy, index: index) {
                            strategyPopupItem = strategy
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.top, 24)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.leading, 23.99)
        .padding(.trailing, 23.99)
        .padding(.top, 24)
        .padding(.bottom, 24)
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

// 策略按钮视图（点击弹出锦囊）- 毛玻璃效果 + 白色文字
struct StrategyButtonView: View {
    let strategy: StrategyItem
    let index: Int
    var onTap: () -> Void = {}
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                if index == 2 {
                    Text("🙈")
                        .font(.system(size: 18))
                } else {
                    Image(systemName: index == 0 ? "heart.fill" : "flame.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                
                Text(strategy.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: index == 2 ? 61.36 : 57.37)
            .background(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.69)
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
            // 拖拽把手
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(hex: "#D1C9BC"))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 18)

            // 标题行
            HStack(alignment: .top, spacing: 10) {
                if let emoji = strategy.emoji, !emoji.isEmpty {
                    Text(emoji)
                        .font(.system(size: 26))
                        .padding(.top, 2)
                }
                Text(strategy.title)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.headerText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(AppColors.headerText.opacity(0.28))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            // 分隔线
            Rectangle()
                .fill(Color(hex: "#E8DCC6"))
                .frame(height: 1)
                .padding(.horizontal, 20)

            // 正文：Markdown 渲染
            ScrollView {
                MarkdownBodyView(content: strategy.content)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 36)
            }
        }
        .background(AppColors.cardBackground)
    }
}

// MARK: - Markdown 块类型（私有）
private enum MDBlock {
    case h2(String)
    case h3(String)
    case bullet(String)
    case body(String)
}

// MARK: - 轻量级 Markdown 渲染（支持 ##/###/列表/加粗斜体）
private struct MarkdownBodyView: View {
    let content: String

    // 将 content 文本解析为有序块列表
    private var blocks: [MDBlock] {
        var result: [MDBlock] = []
        var paraLines: [String] = []

        func flushPara() {
            let text = paraLines.joined(separator: "\n").trimmingCharacters(in: .whitespaces)
            if !text.isEmpty { result.append(.body(text)) }
            paraLines.removeAll()
        }

        for line in content.components(separatedBy: "\n") {
            if line.hasPrefix("### ") {
                flushPara()
                result.append(.h3(String(line.dropFirst(4))))
            } else if line.hasPrefix("## ") {
                flushPara()
                result.append(.h2(String(line.dropFirst(3))))
            } else if line.hasPrefix("# ") {
                flushPara()
                result.append(.h2(String(line.dropFirst(2))))
            } else if line.hasPrefix("- ") || line.hasPrefix("• ") {
                flushPara()
                result.append(.bullet(String(line.dropFirst(2))))
            } else if line.hasPrefix("* ") {
                flushPara()
                result.append(.bullet(String(line.dropFirst(2))))
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                flushPara()
            } else {
                paraLines.append(line)
            }
        }
        flushPara()
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { idx, block in
                mdBlockView(block, isFirst: idx == 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 渲染单个 Markdown 块
    @ViewBuilder
    private func mdBlockView(_ block: MDBlock, isFirst: Bool) -> some View {
        switch block {

        // ## 一级标题：大字加粗，顶部大间距
        case .h2(let text):
            mdText(text)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.headerText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, isFirst ? 0 : 28)
                .padding(.bottom, 8)

        // ### 二级标题：彩色小标题
        case .h3(let text):
            mdText(text)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#5E7C8B"))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, isFirst ? 0 : 22)
                .padding(.bottom, 10)

        // 列表项：圆点 + 内联 Markdown
        case .bullet(let text):
            HStack(alignment: .top, spacing: 9) {
                Circle()
                    .fill(Color(hex: "#8B9E6A"))
                    .frame(width: 5, height: 5)
                    .padding(.top, 8)
                mdText(text)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(AppColors.headerText.opacity(0.83))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 7)

        // 正文段落：内联 Markdown，行距舒适
        case .body(let text):
            mdText(text)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(AppColors.headerText.opacity(0.78))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 12)
        }
    }

    // 用 AttributedString 渲染内联 Markdown（**bold**、_italic_、`code`）
    // 失败时降级为纯文本
    @ViewBuilder
    private func mdText(_ raw: String) -> some View {
        if let attributed = try? AttributedString(
            markdown: raw,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
        } else {
            Text(raw)
        }
    }
}

// 毛玻璃衍射底纹（场景图强模糊，用作情商亮点区域背景）
struct FrostedGlassDiffractionBackground: View {
    let imageUrl: String?

    var body: some View {
        Group {
            if let imageUrl = imageUrl {
                ImageLoaderView(
                    imageUrl: imageUrl,
                    imageBase64: nil,
                    placeholder: "",
                    contentMode: .fill
                )
            } else {
                Color.clear
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .scaleEffect(1.15)
        .blur(radius: 55)
        .opacity(0.28)
        .overlay(Color.black.opacity(0.12))
        .clipped()
    }
}

// 场景还原图片轮播（支持左右滑动查看多张）
// 图片生成使用 4:3 比例，此处与后端一致避免拉伸/裁剪
struct SceneRestoreImageCarouselView: View {
    let sceneImages: [SceneImage]
    var baseURL: String = ""
    @State private var currentIndex: Int = 0
    @State private var showFullScreen = false
    @State private var fullScreenInitialIndex: Int = 0
    private let imageAspectRatio: CGFloat = 4.0 / 3.0

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = width / imageAspectRatio
            if sceneImages.isEmpty {
                // 无图片时显示灰色占位区，保持布局稳定
                Color(hex: "#F5F3EF")
                    .frame(width: width, height: height)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 28))
                                .foregroundColor(Color(hex: "#C4B89A").opacity(0.6))
                            Text("场景还原图生成中")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#9B8C74").opacity(0.8))
                        }
                    )
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(sceneImages.enumerated()), id: \.element.id) { index, sceneImage in
                        SceneRestoreImageView(
                            sceneImage: sceneImage,
                            baseURL: baseURL,
                            onTap: {
                                fullScreenInitialIndex = index
                                showFullScreen = true
                            }
                        )
                        .frame(width: width, height: height)
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: sceneImages.count > 1 ? .automatic : .never))
                .frame(width: width, height: height)
                .onAppear {
                    UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(red: 94/255, green: 124/255, blue: 139/255, alpha: 1)
                    UIPageControl.appearance().pageIndicatorTintColor = UIColor(red: 232/255, green: 220/255, blue: 198/255, alpha: 1)
                }
            }
        }
        .aspectRatio(imageAspectRatio, contentMode: .fit)
        .fullScreenCover(isPresented: $showFullScreen) {
            let items = sceneImages.map { (imageUrl: $0.getAccessibleImageURL(baseURL: baseURL), imageBase64: $0.imageBase64) }
            FullScreenImageViewer(
                items: items,
                initialIndex: fullScreenInitialIndex,
                baseURL: baseURL
            ) {
                showFullScreen = false
            }
        }
    }
}

// 场景还原图片视图（根据Figma设计）- 点击全屏，长按保存
struct SceneRestoreImageView: View {
    let sceneImage: SceneImage
    var baseURL: String = ""
    var onTap: (() -> Void)?

    @ViewBuilder
    private var imageFromBase64Placeholder: some View {
        if let b64 = sceneImage.imageBase64, !b64.isEmpty,
           let data = Data(base64Encoded: b64),
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
        } else {
            Color(hex: "#F9FAFB")
        }
    }

    var body: some View {
        Button(action: { onTap?() }) {
            ZStack(alignment: .bottomLeading) {
                // 图片区域：严格限制在占位区内，填满且不超出
                Group {
                if let imageUrl = sceneImage.getAccessibleImageURL(baseURL: baseURL) {
                    ImageLoaderView(imageUrl: imageUrl, imageBase64: sceneImage.imageBase64, placeholder: "加载中", contentMode: .fill)
                } else if let b64 = sceneImage.imageBase64, !b64.isEmpty {
                    imageFromBase64Placeholder
                } else {
                    Color(hex: "#F9FAFB")
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .aspectRatio(4/3, contentMode: .fill)
            .clipped()

            // 底部渐变遮罩
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.5),
                    Color.black.opacity(0)
                ]),
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .aspectRatio(4/3, contentMode: .fill)
            .allowsHitTesting(false)
            
            // 底部文字内容
            VStack(alignment: .leading, spacing: 3.998422622680664) { // 根据Figma: gap 3.99px
                Text("场景还原")
                    .font(.system(size: 12, weight: .bold, design: .rounded)) // Nunito 700, 12px
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.31)
                    .background(Color.black.opacity(0.5)) // 根据Figma: rgba(0, 0, 0, 0.5)
                    .cornerRadius(4) // 根据Figma: borderRadius 4px
                
                Text("\"\(sceneImage.sceneDescription)\"")
                    .font(.system(size: 18, weight: .bold, design: .rounded)) // Nunito 700, 18px
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 0) // 根据Figma: boxShadow
            }
            .padding(.leading, 23.99)
            .padding(.bottom, 24) // 底部内边距
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .aspectRatio(4/3, contentMode: .fit) // 与后端生成 4:3 图片一致
        .clipped()
        .cornerRadius(24)
    }
}

