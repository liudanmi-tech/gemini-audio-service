//
//  SkillsView.swift
//  WorkSurvivalGuide
//
//  技能库：顶部显示用户 onboarding 选择的 My Focus，下方为完整 6 类体系
//

import SwiftUI

struct SkillsView: View {
    @AppStorage("onboarding_categories") private var savedCategories = ""
    @AppStorage("onboarding_subskills")  private var savedSubSkills  = ""

    @State private var selectedSkill: OnboardingSubSkill? = nil
    @State private var expandedCategories: Set<String> = []

    // 用户在 onboarding 选择的 category/subskill ids
    private var focusCategoryIds: Set<String> {
        Set(savedCategories.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }
    private var focusSubSkillIds: Set<String> {
        Set(savedSubSkills.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    // 用户选择的分类（有序）
    private var focusCategories: [OnboardingCategory] {
        SkillCategoryPresets.all.filter { focusCategoryIds.contains($0.id) }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // ── 页面标题 ──
                Text("Skill Library")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(0.6)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                // ── My Focus（onboarding 选择的分类）──
                if !focusCategories.isEmpty {
                    myFocusSection
                        .padding(.bottom, 28)
                }

                // ── 完整技能库 ──
                VStack(alignment: .leading, spacing: 0) {
                    Text("Full Library")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(1.2)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    ForEach(SkillCategoryPresets.all) { category in
                        SkillCategorySection(
                            category: category,
                            focusSubSkillIds: focusSubSkillIds,
                            isExpanded: expandedCategories.contains(category.id),
                            onToggleExpand: {
                                if expandedCategories.contains(category.id) {
                                    expandedCategories.remove(category.id)
                                } else {
                                    expandedCategories.insert(category.id)
                                }
                            },
                            onSelectSkill: { selectedSkill = $0 }
                        )
                        .padding(.bottom, 24)
                    }
                }

                Spacer(minLength: 120)
            }
        }
        .sheet(item: $selectedSkill) { skill in
            SubSkillDetailSheet(skill: skill, isFocused: focusSubSkillIds.contains(skill.id))
        }
    }

    // MARK: - My Focus Section

    private var myFocusSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 标题行
            HStack {
                Label("My Focus", systemImage: "star.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(1.2)
                Spacer()
            }
            .padding(.horizontal, 20)

            // 分类 Tabs（横向滚动）
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(focusCategories) { category in
                        FocusCategoryPill(category: category)
                    }
                }
                .padding(.horizontal, 20)
            }

            // 选中的子技能
            if !focusSubSkillIds.isEmpty {
                VStack(spacing: 8) {
                    ForEach(focusCategories) { category in
                        let focused = category.subSkills.filter { focusSubSkillIds.contains($0.id) }
                        if !focused.isEmpty {
                            ForEach(focused) { skill in
                                FocusSubSkillRow(skill: skill, emoji: category.emoji) {
                                    selectedSkill = skill
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Focus Category Pill

private struct FocusCategoryPill: View {
    let category: OnboardingCategory

    var body: some View {
        HStack(spacing: 6) {
            Text(category.emoji).font(.system(size: 14))
            Text(category.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color.blue.opacity(0.2))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.blue.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - Focus SubSkill Row

private struct FocusSubSkillRow: View {
    let skill: OnboardingSubSkill
    let emoji: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(emoji)
                    .font(.system(size: 16))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text(skill.description)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Skill Category Section (Full Library)

private struct SkillCategorySection: View {
    let category: OnboardingCategory
    let focusSubSkillIds: Set<String>
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onSelectSkill: (OnboardingSubSkill) -> Void

    private let previewCount = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 分类标题行
            Button(action: onToggleExpand) {
                HStack(spacing: 10) {
                    Text(category.emoji).font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.name)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(category.description)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            // 子技能网格
            let displayed = isExpanded ? category.subSkills : Array(category.subSkills.prefix(previewCount))
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(displayed) { skill in
                    SubSkillCard(
                        skill: skill,
                        isFocused: focusSubSkillIds.contains(skill.id),
                        onTap: { onSelectSkill(skill) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)

            // "Show more / less" 按钮
            if category.subSkills.count > previewCount {
                Button(action: onToggleExpand) {
                    Text(isExpanded
                         ? "Show less"
                         : "+ \(category.subSkills.count - previewCount) more")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
        }
    }
}

// MARK: - SubSkill Card

private struct SubSkillCard: View {
    let skill: OnboardingSubSkill
    let isFocused: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    if isFocused {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.2))
                }

                Text(skill.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(skill.description)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isFocused ? Color.blue.opacity(0.12) : Color.white.opacity(0.06))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SubSkill Detail Sheet

struct SubSkillDetailSheet: View {
    let skill: OnboardingSubSkill
    let isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    // 每个技能的 tips（静态内容，后续可替换为 AI 生成）
    private var tips: [String] {
        skillTips[skill.id] ?? [
            "Use the recording feature to practice a real conversation.",
            "After recording, AI will analyze your communication patterns.",
            "Review the feedback and try again in your next conversation."
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // ── 标题区 ──
                        VStack(alignment: .leading, spacing: 8) {
                            Text(skill.name)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)

                            Text(skill.description)
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.top, 8)

                        // ── What you'll learn ──
                        VStack(alignment: .leading, spacing: 12) {
                            Text("HOW IT WORKS")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.35))
                                .tracking(1.2)

                            VStack(spacing: 10) {
                                ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                                    HStack(alignment: .top, spacing: 12) {
                                        Circle()
                                            .fill(Color.blue.opacity(0.7))
                                            .frame(width: 6, height: 6)
                                            .padding(.top, 6)
                                        Text(tip)
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(14)

                        // ── Practice prompt ──
                        VStack(alignment: .leading, spacing: 10) {
                            Text("PRACTICE")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.35))
                                .tracking(1.2)

                            Text("Record a real conversation where this skill is relevant. The AI will analyze your patterns and give you actionable feedback.")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                                .lineSpacing(3)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(14)

                        if isFocused {
                            Label("This skill is in your focus list", systemImage: "star.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.blue)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)
                        }

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Static Tips per skill (MVP 占位)
    private let skillTips: [String: [String]] = [
        "salary_negotiation": [
            "Research market rates before the conversation using Glassdoor or Levels.fyi.",
            "Anchor high — the first number sets the range.",
            "Use silence strategically: after stating your ask, wait for their response."
        ],
        "difficult_boss": [
            "Document specific incidents with dates and context.",
            "Focus on impact to the team/project, not personal feelings.",
            "Ask clarifying questions to surface their expectations explicitly."
        ],
        "work_boundaries": [
            "Be direct and brief — long explanations invite negotiation.",
            "Use 'I won't' instead of 'I can't' to own your boundary.",
            "Offer an alternative when possible to soften the no."
        ],
        "roommate_conflicts": [
            "Address issues within 24 hours before resentment builds.",
            "Use 'I notice...' instead of 'You always...'",
            "Agree on house rules in writing at the start."
        ],
        "ghosting_rejection": [
            "A brief, honest message is kinder than silence.",
            "You don't owe anyone a detailed explanation.",
            "Give yourself time before responding if you're upset."
        ],
        "situationship": [
            "Name what you want clearly — vague hints don't work.",
            "Be prepared for any answer, including one you don't want.",
            "The conversation itself tells you a lot about compatibility."
        ],
        "social_anxiety": [
            "Prepare 3 questions before any event to start conversations.",
            "Focus on curiosity about others, not how you're coming across.",
            "It's okay to leave early — giving yourself that permission reduces anxiety."
        ],
        "assertiveness": [
            "Use the 3-part formula: state the fact, your feeling, your need.",
            "Match your body language to your words — eye contact matters.",
            "Practice with low-stakes situations first."
        ],
        "imposter_syndrome": [
            "Keep a 'wins' document — write down every compliment and achievement.",
            "Recognize that most people feel this way, especially high achievers.",
            "Separate feelings from facts: feeling unqualified ≠ being unqualified."
        ],
        "friend_crisis": [
            "Ask directly: 'Are you thinking about hurting yourself?'",
            "Listen without trying to fix — presence matters more than solutions.",
            "Connect them to professional help: 988 Suicide & Crisis Lifeline."
        ],
    ]
}

#Preview {
    SkillsView()
        .preferredColorScheme(.dark)
}
