//
//  OnboardingView.swift
//  WorkSurvivalGuide
//
//  注册后首次引导：Step1 身份 → Step2 场景分类（最多3）
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("onboarding_completed")  private var onboardingCompleted = false
    @AppStorage("onboarding_identity")   private var savedIdentity = ""
    @AppStorage("onboarding_categories") private var savedCategories = ""
    @AppStorage("onboarding_subskills")  private var savedSubSkills = ""

    @State private var step = 1
    @State private var selectedIdentity: UserIdentity? = nil
    @State private var selectedCategories: Set<OnboardingCategory> = []

    private let maxCategories = 3

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── 顶部进度 + Skip ──
                HStack {
                    ProgressDotsView(total: 2, current: step)
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
                    if step == 1 { step1View } else { step2View }
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

    // MARK: - Step 2: 场景选择（最多3个）

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

    // MARK: - 底部按钮

    private var bottomButton: some View {
        VStack(spacing: 0) {
            let isEnabled: Bool = step == 1 ? selectedIdentity != nil : !selectedCategories.isEmpty
            let label: String = step == 2 ? "Get Started" : "Continue"

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
        if step < 2 {
            withAnimation(.easeInOut(duration: 0.25)) { step += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        savedIdentity   = selectedIdentity?.rawValue ?? ""
        savedCategories = selectedCategories.map(\.id).joined(separator: ",")
        // Populate sub-skill selection: all sub-skills of selected categories
        let allSubSkillIds = selectedCategories.flatMap { $0.subSkills.map(\.id) }
        savedSubSkills = allSubSkillIds.joined(separator: ",")
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
    let category: OnboardingCategory
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
