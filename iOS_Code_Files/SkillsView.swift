//
//  SkillsView.swift
//  WorkSurvivalGuide
//
//  技能库：顶部星域卡片，下方展示用户 onboarding 选择的场景及其子技能（横向卡片）
//

import SwiftUI

// MARK: - OnboardingCategory helpers (UI only)

private extension OnboardingCategory {
    var accentColor: Color {
        switch id {
        case "work_life":       return Color(hex: "#45B7D1")
        case "campus_life":     return Color(hex: "#A78BFA")
        case "relationships":   return Color(hex: "#F472B6")
        case "family":          return Color(hex: "#FB923C")
        case "personal_growth": return Color(hex: "#34D399")
        case "life_skills":     return Color(hex: "#FBBF24")
        default:                return Color(hex: "#5E7C8B")
        }
    }
}

// MARK: - OnboardingSubSkill icon helper

private extension OnboardingSubSkill {
    var icon: String {
        switch id {
        case "salary_negotiation":  return "💰"
        case "difficult_boss":      return "⚡"
        case "work_boundaries":     return "🛑"
        case "performance_reviews": return "📊"
        case "feedback":            return "💬"
        case "job_interviews":      return "🎯"
        case "coworker_conflicts":  return "🤝"
        case "remote_work":         return "💻"
        case "roommate_conflicts":  return "🏠"
        case "professor_email":     return "📧"
        case "group_projects":      return "👥"
        case "making_friends":      return "😊"
        case "asking_extensions":   return "⏰"
        case "academic_burnout":    return "🔥"
        case "internship_interview":return "💼"
        case "networking":          return "🌐"
        case "partner_communication":return "💕"
        case "talking_stage":       return "💭"
        case "ghosting_rejection":  return "👻"
        case "situationship":       return "❓"
        case "dtr_conversation":    return "💍"
        case "breakups":            return "💔"
        case "friendship_conflicts":return "🫂"
        case "coming_out":          return "🌈"
        case "parent_boundaries":   return "🛡"
        case "immigrant_family":    return "🌏"
        case "family_money":        return "💵"
        case "coparenting":         return "👶"
        case "parent_teen":         return "🎓"
        case "coming_out_family":   return "🌈"
        case "assertiveness":       return "💪"
        case "imposter_syndrome":   return "🎭"
        case "social_anxiety":      return "😰"
        case "burnout_recovery":    return "🌱"
        case "anger_management":    return "🧘"
        case "friend_crisis":       return "🆘"
        case "dealing_criticism":   return "🪞"
        case "boundary_setting":    return "🔒"
        case "healthcare_advocacy": return "🏥"
        case "customer_service":    return "📞"
        case "money_conversations": return "💸"
        case "neighbor_conflicts":  return "🏘"
        case "landlord_comm":       return "🔑"
        default:                    return "✨"
        }
    }
}

struct SkillsView: View {
    @ObservedObject private var viewModel = SkillsViewModel.shared

    // Source of truth: sub-skill IDs (set by onboarding + SkillAddSheet)
    @AppStorage("onboarding_subskills") private var savedSubSkills = ""
    // Fallback: category IDs written by onboarding (used to seed subskills if empty)
    @AppStorage("onboarding_categories") private var savedCategories = ""

    @State private var selectedSkill: OnboardingSubSkill? = nil
    @State private var showAddSheet = false
    @State private var customSkills: [CustomSkill] = []
    @State private var selectedCustomSkill: CustomSkill? = nil

    private var selectedSubSkillIds: Set<String> {
        Set(savedSubSkills.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    /// Categories that have at least one selected sub-skill, paired with their selected sub-skills only
    private var categoriesWithSelections: [(category: OnboardingCategory, subSkills: [OnboardingSubSkill])] {
        SkillCategoryPresets.all.compactMap { cat in
            let selected = cat.subSkills.filter { selectedSubSkillIds.contains($0.id) }
            return selected.isEmpty ? nil : (cat, selected)
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                SkillsHeaderView(viewModel: viewModel, onAddTap: { showAddSheet = true })

                WeeklyStatsCarouselView()
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                if categoriesWithSelections.isEmpty && customSkills.isEmpty {
                    Spacer()
                    VStack(spacing: 14) {
                        Image(systemName: "list.star")
                            .font(.system(size: 44))
                            .foregroundColor(.white.opacity(0.3))
                        Text("No focus areas selected")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                        Text("Tap + to add skills to your library.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.white.opacity(0.3))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    Spacer()
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 28) {
                            ForEach(categoriesWithSelections, id: \.category.id) { item in
                                OnboardingCategorySection(
                                    category: item.category,
                                    displaySubSkills: item.subSkills,
                                    onSelectSkill: { selectedSkill = $0 }
                                )
                            }

                            if !customSkills.isEmpty {
                                CustomSkillsSection(
                                    skills: customSkills,
                                    onSelectSkill: { selectedCustomSkill = $0 },
                                    onDelete: { id in deleteCustomSkill(id: id) }
                                )
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 120)
                    }
                }
            }
        }
        .onAppear {
            if viewModel.categories.isEmpty && !viewModel.isLoading {
                viewModel.loadCatalog()
            }
            // Seed subskills from categories if this is a user who onboarded before the sub-skill update
            if savedSubSkills.isEmpty && !savedCategories.isEmpty {
                let catIds = Set(savedCategories.split(separator: ",").map(String.init))
                let allSubIds = SkillCategoryPresets.all
                    .filter { catIds.contains($0.id) }
                    .flatMap { $0.subSkills.map(\.id) }
                savedSubSkills = allSubIds.joined(separator: ",")
            }
            // Default: if user skipped onboarding entirely, seed with relationships + family + personal growth
            if savedSubSkills.isEmpty && savedCategories.isEmpty {
                let defaultIds: Set<String> = ["relationships", "family", "personal_growth"]
                let allSubIds = SkillCategoryPresets.all
                    .filter { defaultIds.contains($0.id) }
                    .flatMap { $0.subSkills.map(\.id) }
                savedCategories = defaultIds.joined(separator: ",")
                savedSubSkills  = allSubIds.joined(separator: ",")
            }
            loadCustomSkills()
        }
        .onReceive(NotificationCenter.default.publisher(for: .customSkillsDidChange)) { _ in
            loadCustomSkills()
        }
        .onChange(of: savedSubSkills) { newValue in
            guard !newValue.isEmpty else { return }
            let skillIds = newValue.split(separator: ",").map(String.init).filter { !$0.isEmpty }
            Task {
                try? await NetworkManager.shared.updateSkillPreferences(selectedSkills: skillIds)
            }
        }
        .sheet(item: $selectedSkill) { skill in
            OnboardingSubSkillDetailSheet(skill: skill)
        }
        .sheet(item: $selectedCustomSkill) { skill in
            CustomSkillDetailSheet(skill: skill)
        }
        .sheet(isPresented: $showAddSheet, onDismiss: loadCustomSkills) {
            SkillAddSheet()
        }
    }

    private func loadCustomSkills() {
        Task {
            let skills = (try? await NetworkManager.shared.listCustomSkills()) ?? []
            await MainActor.run { customSkills = skills }
        }
    }

    private func deleteCustomSkill(id: String) {
        Task {
            try? await NetworkManager.shared.deleteCustomSkill(skillId: id)
            await MainActor.run {
                customSkills.removeAll { $0.id == id }
            }
        }
    }
}

// MARK: - Onboarding Category Section

private struct OnboardingCategorySection: View {
    let category: OnboardingCategory
    let displaySubSkills: [OnboardingSubSkill]   // only the selected sub-skills to display
    let onSelectSkill: (OnboardingSubSkill) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(category.emoji)
                    .font(.system(size: 18))
                Text(category.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("\(displaySubSkills.count) skill\(displaySubSkills.count == 1 ? "" : "s")")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(displaySubSkills) { skill in
                        OnboardingSubSkillCard(
                            skill: skill,
                            accentColor: category.accentColor
                        ) {
                            onSelectSkill(skill)
                        }
                        .frame(width: cardWidth)
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

// MARK: - Onboarding SubSkill Card

private struct OnboardingSubSkillCard: View {
    let skill: OnboardingSubSkill
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // 顶部色块（对应 SkillCatalogCardView 的 coverGradient 区域）
                ZStack {
                    LinearGradient(
                        colors: [accentColor.opacity(0.85), accentColor.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Text(skill.icon)
                        .font(.system(size: 40))
                        .opacity(0.7)
                }
                .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // 名称 + 描述
                VStack(alignment: .leading, spacing: 4) {
                    Text(skill.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(skill.description)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                        .lineSpacing(2)
                }
                .padding(.horizontal, 8)
                .padding(.top, 10)
                .padding(.bottom, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(white: 0.13))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Onboarding SubSkill Detail Sheet

struct OnboardingSubSkillDetailSheet: View {
    let skill: OnboardingSubSkill
    @Environment(\.dismiss) private var dismiss

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

                        VStack(alignment: .leading, spacing: 8) {
                            Text(skill.name)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                            Text(skill.description)
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.top, 8)

                        // HOW IT WORKS
                        VStack(alignment: .leading, spacing: 12) {
                            Text("HOW IT WORKS")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.35))
                                .tracking(1.2)

                            VStack(spacing: 10) {
                                ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                                    HStack(alignment: .top, spacing: 12) {
                                        Circle()
                                            .fill(Color(hex: "#45B7D1").opacity(0.7))
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

                        // PRACTICE
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
        "performance_reviews": [
            "Prepare a list of accomplishments with measurable impact before the meeting.",
            "Ask for specific feedback, not just ratings.",
            "Follow up in writing to confirm any commitments made."
        ],
        "feedback": [
            "Use the SBI model: Situation, Behavior, Impact.",
            "Separate the person from the behavior when giving feedback.",
            "Ask 'What would you do differently?' instead of telling them what to change."
        ],
        "job_interviews": [
            "Use the STAR method: Situation, Task, Action, Result.",
            "Prepare 3-5 stories that can answer behavioral questions.",
            "Research the company's recent news and reference it in your answers."
        ],
        "coworker_conflicts": [
            "Address issues privately before escalating to management.",
            "Focus on the shared goal, not who's right.",
            "Assume positive intent until proven otherwise."
        ],
        "remote_work": [
            "Over-communicate progress — don't wait to be asked for updates.",
            "Set clear response time expectations in your bio or calendar.",
            "Use async-friendly formats: loom videos, detailed written updates."
        ],
        "roommate_conflicts": [
            "Address issues within 24 hours before resentment builds.",
            "Use 'I notice...' instead of 'You always...'",
            "Agree on house rules in writing at the start."
        ],
        "professor_email": [
            "Keep emails under 100 words — professors read hundreds a week.",
            "Reference the class name and section in the subject line.",
            "Show you've already tried to find the answer before asking."
        ],
        "group_projects": [
            "Establish roles and deadlines in the first meeting.",
            "Use a shared doc to track who owns what.",
            "Address slackers early — wait too long and it becomes resentment."
        ],
        "making_friends": [
            "Proximity + repetition is the formula — show up consistently.",
            "Ask follow-up questions about things they mentioned before.",
            "Be the one to suggest a specific plan, not just 'we should hang out.'"
        ],
        "asking_extensions": [
            "Ask before the deadline, not after.",
            "Be honest about the reason — professors respect transparency.",
            "Propose your own new deadline to show you're in control."
        ],
        "academic_burnout": [
            "Identify what's draining you: workload, purpose, or environment.",
            "Schedule non-negotiable rest — recovery is part of performance.",
            "Talk to an advisor or counselor before it compounds."
        ],
        "internship_interview": [
            "Research the company's products and recent news beforehand.",
            "Have 2-3 questions ready that show genuine curiosity.",
            "Follow up with a thank-you email within 24 hours."
        ],
        "networking": [
            "Lead with genuine curiosity about their work, not asks.",
            "Follow up within 48 hours with something specific from your conversation.",
            "Give before you ask — share a resource, make an intro, offer help."
        ],
        "partner_communication": [
            "Use 'I feel...' statements instead of 'You always...'",
            "Pick the right time — don't bring up big topics when tired or hungry.",
            "Aim to understand, not to win the argument."
        ],
        "talking_stage": [
            "Be clear about your intentions early — saves everyone time.",
            "Consistency matters more than intensity.",
            "If you're unsure how they feel, just ask directly."
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
        "dtr_conversation": [
            "Choose a calm, private moment — not after a conflict.",
            "Be honest about what you're looking for, not what you think they want to hear.",
            "If they can't answer, that is an answer."
        ],
        "breakups": [
            "Do it in person or by call — not text.",
            "Be kind but clear — vague language gives false hope.",
            "Don't offer friendship in the moment if you don't mean it."
        ],
        "friendship_conflicts": [
            "Address it directly with the person, not through mutual friends.",
            "Give it a day before reaching out if emotions are high.",
            "Decide if this is a pattern or a one-time thing — that changes your approach."
        ],
        "coming_out": [
            "Choose someone you trust first — you don't have to do it all at once.",
            "You get to control when, how, and to whom.",
            "Have a support person ready for after difficult conversations."
        ],
        "parent_boundaries": [
            "Be direct and brief — long explanations invite negotiation.",
            "Use 'I won't' instead of 'I can't' to own your boundary.",
            "Offer an alternative when possible to soften the no."
        ],
        "immigrant_family": [
            "Acknowledge their sacrifices before bringing up your needs.",
            "Find common values (safety, success, respect) to anchor the conversation.",
            "Use concrete examples, not abstract concepts like 'independence.'"
        ],
        "family_money": [
            "Talk about money when everyone is calm, not during a crisis.",
            "Use numbers and facts, not emotions.",
            "Establish clear agreements in writing, even for family loans."
        ],
        "coparenting": [
            "Keep the kids completely out of adult disagreements.",
            "Communicate in writing to avoid misunderstandings.",
            "Focus on what's best for the child, not winning against your ex."
        ],
        "parent_teen": [
            "Listen twice as much as you talk.",
            "Pick your battles — not everything needs a rule.",
            "Share your own mistakes — it builds trust and relatability."
        ],
        "coming_out_family": [
            "Plan the conversation when you're in a safe, stable place.",
            "Have a backup plan if the reaction is difficult.",
            "You are not responsible for managing their feelings."
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
        "social_anxiety": [
            "Prepare 3 questions before any event to start conversations.",
            "Focus on curiosity about others, not how you're coming across.",
            "It's okay to leave early — giving yourself that permission reduces anxiety."
        ],
        "burnout_recovery": [
            "Start by doing less, not trying harder.",
            "Identify which type of rest you need: physical, mental, emotional, or social.",
            "Recovery takes longer than you expect — be patient with yourself."
        ],
        "anger_management": [
            "Name the emotion — labeling it reduces its intensity.",
            "Buy time: 'I need a moment before I respond.'",
            "Look for the need underneath the anger — what are you actually protecting?"
        ],
        "friend_crisis": [
            "Ask directly: 'Are you thinking about hurting yourself?'",
            "Listen without trying to fix — presence matters more than solutions.",
            "Connect them to professional help: 988 Suicide & Crisis Lifeline."
        ],
        "dealing_criticism": [
            "Pause before responding — a few seconds makes a big difference.",
            "Ask clarifying questions to understand the feedback fully.",
            "Separate useful critique from how it was delivered."
        ],
        "boundary_setting": [
            "Be direct and brief — long explanations invite negotiation.",
            "Use 'I won't' instead of 'I can't' to own your boundary.",
            "Offer an alternative when possible to soften the no."
        ],
        "healthcare_advocacy": [
            "Write down your symptoms and questions before the appointment.",
            "Ask 'What are all the options?' not just 'What do you recommend?'",
            "Request everything in writing — especially diagnoses and treatment plans."
        ],
        "customer_service": [
            "Stay calm and factual — emotion gives them an excuse to dismiss you.",
            "Ask for a supervisor if the first rep can't help.",
            "Know your consumer rights — many companies have policies they don't advertise."
        ],
        "money_conversations": [
            "Address it early — awkward now beats resentment later.",
            "Propose a specific system instead of leaving it vague.",
            "Keep a shared record of who owes what."
        ],
        "neighbor_conflicts": [
            "Start with a friendly, in-person conversation before formal action.",
            "Document incidents with dates and times if they continue.",
            "Know your local noise and parking ordinances before citing them."
        ],
        "landlord_comm": [
            "Always communicate in writing — email creates a paper trail.",
            "Know your tenant rights in your state before negotiating.",
            "Be specific about timelines: 'By Friday' beats 'soon.'"
        ],
    ]
}

// MARK: - Header (unchanged)

struct SkillsHeaderView: View {
    @ObservedObject var viewModel: SkillsViewModel
    var onAddTap: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("Skill Library")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .tracking(0.6)

            Spacer()

            // Add skills button
            Button(action: { onAddTap?() }) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)

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

// MARK: - Custom Skills Section

private struct CustomSkillsSection: View {
    let skills: [CustomSkill]
    let onSelectSkill: (CustomSkill) -> Void
    let onDelete: (String) -> Void

    private let accentColor = Color(hex: "#A78BFA")  // Purple for custom skills

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("✨")
                    .font(.system(size: 18))
                Text("Custom Skills")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("\(skills.count) skill\(skills.count == 1 ? "" : "s")")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(skills) { skill in
                        CustomSkillCard(
                            skill: skill,
                            accentColor: accentColor,
                            onTap: { onSelectSkill(skill) },
                            onDelete: { onDelete(skill.id) }
                        )
                        .frame(width: (UIScreen.main.bounds.width - 52) / 2)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

private struct CustomSkillCard: View {
    let skill: CustomSkill
    let accentColor: Color
    let onTap: () -> Void
    let onDelete: () -> Void
    @State private var showDeleteConfirm = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    LinearGradient(
                        colors: [accentColor.opacity(0.85), accentColor.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    VStack(spacing: 4) {
                        Text("✨")
                            .font(.system(size: 36))
                            .opacity(0.7)
                        Text("Custom")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(0.8)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    Button(action: { showDeleteConfirm = true }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(skill.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(skill.description ?? "Custom skill guide")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                        .lineSpacing(2)
                }
                .padding(.horizontal, 8)
                .padding(.top, 10)
                .padding(.bottom, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(white: 0.13))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(accentColor.opacity(0.25), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .confirmationDialog("Remove this skill?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Custom Skill Detail Sheet

struct CustomSkillDetailSheet: View {
    let skill: CustomSkill
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text("✨")
                                    .font(.system(size: 20))
                                Text("Custom Skill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(hex: "#A78BFA"))
                                    .tracking(0.8)
                            }
                            Text(skill.name)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                            if let desc = skill.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineSpacing(3)
                            }
                        }
                        .padding(.top, 8)

                        if let md = skill.markdown_content, !md.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("SKILL GUIDE")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.35))
                                    .tracking(1.2)
                                Text(md)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineSpacing(4)
                                    .padding(16)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(14)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("PRACTICE")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.35))
                                .tracking(1.2)
                            Text("Record a real conversation where this skill is relevant. The AI will use this custom skill guide to analyze your conversation and give personalized feedback.")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                                .lineSpacing(3)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(14)

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
}

#Preview {
    SkillsView()
}
