//
//  SkillsView.swift
//  WorkSurvivalGuide
//

import SwiftUI

struct SkillsView: View {
    @ObservedObject private var viewModel = SkillsViewModel.shared

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                SkillsHeaderView(viewModel: viewModel)

                if viewModel.isLoading && viewModel.categories.isEmpty {
                    Spacer()
                    ProgressView("加载中...")
                        .tint(.white)
                    Spacer()
                } else if viewModel.categories.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.4))
                        Text("No skills yet")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                        if let err = viewModel.errorMessage {
                            Text(err)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.red.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        Button("Reload") {
                            viewModel.loadCatalog(forceRefresh: true)
                        }
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color(hex: "#5E7C8B")))
                    }
                    Spacer()
                } else {
                    // Constellation banner — fixed above the scrollable list
                    SkillConstellationView()
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 28) {
                            // 模式说明文字
                            modeHintText
                                .padding(.horizontal, 20)
                                .padding(.top, 4)

                            ForEach(viewModel.sortedCategories) { category in
                                CategorySection(
                                    category: category,
                                    viewModel: viewModel
                                )
                            }
                        }
                        .padding(.bottom, 120)
                    }
                }
            }
        }
        .onAppear {
            if viewModel.categories.isEmpty && !viewModel.isLoading {
                viewModel.loadCatalog()
            }
        }
        .sheet(item: $viewModel.selectedSkillForDetail) { skill in
            SkillDetailSheet(
                skill: skill,
                isSelected: viewModel.isSkillSelected(skill.skillId),
                onToggle: { viewModel.toggleSkill(skill.skillId) }
            )
        }
    }

    @ViewBuilder
    private var modeHintText: some View {
        if viewModel.isManualMode {
            let count = viewModel.manualSelectedCount
            Text(count == 0
                 ? "Manual mode: Select skills to match during recording."
                 : "Manual mode: \(count) skill(s) selected for matching.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "#E8A44A").opacity(0.85))
        } else {
            Text("Auto mode: System intelligently matches the best skills from your recording.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

// MARK: - Category Section

private struct CategorySection: View {
    let category: SkillCategory
    @ObservedObject var viewModel: SkillsViewModel

    private var categoryIcon: String {
        switch category.id {
        case "workplace": return "briefcase"
        case "family": return "house"
        case "personal": return "person.crop.circle"
        default: return "chart.line.uptrend.xyaxis"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            HStack(spacing: 8) {
                Image(systemName: categoryIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                Text(category.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)

            // Horizontal scrolling cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(category.skills) { skill in
                        SkillCatalogCardView(
                            skill: skill,
                            isSelected: viewModel.isSkillSelected(skill.skillId),
                            isManualMode: viewModel.isManualMode,
                            onToggle: { viewModel.toggleSkill(skill.skillId) },
                            onTapCover: { viewModel.showDetail(skill) }
                        )
                        .frame(width: cardWidth)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.isManualMode)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var cardWidth: CGFloat {
        (UIScreen.main.bounds.width - 52) / 2
    }
}

// MARK: - Header

struct SkillsHeaderView: View {
    @ObservedObject var viewModel: SkillsViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("Skill Library")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .tracking(0.6)

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.toggleMode()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isManualMode ? "hand.tap" : "sparkles")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    Text(viewModel.isManualMode ? "Manual" : "Auto")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(
                    Capsule()
                        .fill(viewModel.isManualMode
                              ? Color(hex: "#C07A28")
                              : Color(hex: "#5E7C8B"))
                )
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.isManualMode)
        }
        .padding(.horizontal, 24)
        .frame(height: 60)
    }
}

#Preview {
    SkillsView()
        .preferredColorScheme(.dark)
}
