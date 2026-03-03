//
//  OnboardingView.swift
//  WorkSurvivalGuide
//
//  注册后首次引导：Step1 身份 → Step2 分类（最多3）→ Step3 子技能
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("onboarding_completed")  private var onboardingCompleted = false
    @AppStorage("onboarding_identity")   private var savedIdentity = ""
    @AppStorage("onboarding_categories") private var savedCategories = ""
    @AppStorage("onboarding_subskills")  private var savedSubSkills = ""

    @State private var step = 1
    @State private var selectedIdentity: UserIdentity? = nil
    @State private var selectedCategories: Set<SkillCategory> = []
    @State private var selectedSubSkills: Set<SubSkillItem> = []

    private let maxCategories = 3

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── 顶部进度 + Skip ──
                HStack {
                    ProgressDotsView(total: 3, current: step)
                    Spacer()
                    Button("Skip") { finish() }
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 8)

                // ── 步骤内容 ──
                Group {
                    switch step {
                    case 1: step1View
                    case 2: step2View
                    default: step3View
                    }
                }

                // ── 底部按钮 ──
                bottomButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Step 1: 身份选择

    private var step1View: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                VStack(spacing: 10) {
                    Text("Who are you?")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text("We'll personalize your experience")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.top, 24)

                VStack(spacing: 14) {
                    ForEach(UserIdentity.allCases) { identity in
                        IdentityCard(
                            identity: identity,
                            isSelected: selectedIdentity == identity
                        ) {
                            selectedIdentity = identity
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Step 2: 分类选择（最多3个）

    private var step2View: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                VStack(spacing: 10) {
                    Text("What do you need help with?")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Text("Pick up to \(maxCategories) areas")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.top, 24)
                .padding(.horizontal, 24)

                let categories = SkillCategoryPresets.categories(for: selectedIdentity ?? .both)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(categories) { category in
                        CategoryCard(
                            category: category,
                            isSelected: selectedCategories.contains(category),
                            isDisabled: !selectedCategories.contains(category) && selectedCategories.count >= maxCategories
                        ) {
                            if selectedCategories.contains(category) {
                                selectedCategories.remove(category)
                            } else if selectedCategories.count < maxCategories {
                                selectedCategories.insert(category)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Step 3: 子技能选择

    private var step3View: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                VStack(spacing: 10) {
                    Text("Choose your focus areas")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Text("Select all that apply")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.top, 24)
                .padding(.horizontal, 24)

                ForEach(Array(selectedCategories).sorted(by: { $0.name < $1.name })) { category in
                    VStack(alignment: .leading, spacing: 12) {
                        // 分类标题
                        HStack(spacing: 8) {
                            Text(category.emoji)
                                .font(.system(size: 18))
                            Text(category.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 24)

                        // 子技能列表
                        VStack(spacing: 8) {
                            ForEach(category.subSkills) { skill in
                                SubSkillRow(
                                    skill: skill,
                                    isSelected: selectedSubSkills.contains(skill)
                                ) {
                                    if selectedSubSkills.contains(skill) {
                                        selectedSubSkills.remove(skill)
                                    } else {
                                        selectedSubSkills.insert(skill)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }

                Spacer(minLength: 16)
            }
        }
    }

    // MARK: - 底部按钮

    private var bottomButton: some View {
        VStack(spacing: 0) {
            let isEnabled: Bool = {
                switch step {
                case 1: return selectedIdentity != nil
                case 2: return !selectedCategories.isEmpty
                default: return true
                }
            }()

            let label: String = step == 3 ? "Get Started" : "Continue"

            Button(action: advance) {
                Text(label)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(isEnabled ? Color.blue : Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(!isEnabled)
            .padding(.top, 16)
        }
    }

    // MARK: - Navigation

    private func advance() {
        if step < 3 {
            withAnimation(.easeInOut(duration: 0.25)) { step += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        // 存到 UserDefaults
        savedIdentity   = selectedIdentity?.rawValue ?? ""
        savedCategories = selectedCategories.map(\.id).joined(separator: ",")
        savedSubSkills  = selectedSubSkills.map(\.id).joined(separator: ",")
        onboardingCompleted = true
    }
}

// MARK: - ProgressDotsView

private struct ProgressDotsView: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...total, id: \.self) { i in
                Capsule()
                    .frame(width: i == current ? 20 : 8, height: 8)
                    .foregroundColor(i <= current ? Color.blue : Color.white.opacity(0.2))
                    .animation(.spring(response: 0.3), value: current)
            }
        }
    }
}

// MARK: - IdentityCard

private struct IdentityCard: View {
    let identity: UserIdentity
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Text(identity.emoji)
                    .font(.system(size: 32))
                    .frame(width: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(identity.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text(identity.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.55))
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .blue : .white.opacity(0.25))
            }
            .padding(16)
            .background(isSelected ? Color.blue.opacity(0.15) : Color.white.opacity(0.07))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.blue.opacity(0.6) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - CategoryCard

private struct CategoryCard: View {
    let category: SkillCategory
    let isSelected: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(category.emoji)
                        .font(.system(size: 28))
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .blue : .white.opacity(0.25))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(category.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isDisabled && !isSelected ? .white.opacity(0.35) : .white)
                        .lineLimit(1)
                    Text(category.description)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(isDisabled && !isSelected ? 0.25 : 0.5))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.blue.opacity(0.15) : Color.white.opacity(0.07))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.blue.opacity(0.6) : Color.clear, lineWidth: 1.5)
            )
            .opacity(isDisabled && !isSelected ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled && !isSelected)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - SubSkillRow

private struct SubSkillRow: View {
    let skill: SubSkillItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .blue : .white.opacity(0.3))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    Text(skill.description)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.45))
                }

                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(isSelected ? Color.blue.opacity(0.12) : Color.white.opacity(0.05))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
    }
}
