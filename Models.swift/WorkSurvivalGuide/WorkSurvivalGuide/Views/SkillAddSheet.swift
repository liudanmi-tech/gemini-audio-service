//
//  SkillAddSheet.swift
//  WorkSurvivalGuide
//
//  技能添加 Sheet：系统技能库（勾选场景/子技能）+ 自定义技能（AI 生成）
//

import SwiftUI

// MARK: - Main Sheet

struct SkillAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Tab Picker
                    Picker("", selection: $selectedTab) {
                        Text("System Library").tag(0)
                        Text("Custom Skill").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                    if selectedTab == 0 {
                        SystemLibraryTab()
                    } else {
                        CustomSkillTab()
                    }
                }
            }
            .navigationTitle("Add Skills")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
}

// MARK: - System Library Tab

private struct SystemLibraryTab: View {
    @AppStorage("onboarding_subskills") private var savedSubSkills = ""

    private var selectedSubSkillIds: Set<String> {
        Set(savedSubSkills.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    private func isSubSkillSelected(_ id: String) -> Bool { selectedSubSkillIds.contains(id) }

    /// true=all selected, false=none, nil=partial
    private func categoryState(_ category: OnboardingCategory) -> Bool? {
        let ids = category.subSkills.map(\.id)
        let selectedCount = ids.filter { selectedSubSkillIds.contains($0) }.count
        if selectedCount == 0 { return false }
        if selectedCount == ids.count { return true }
        return nil  // partial
    }

    private func toggleSubSkill(_ id: String) {
        var ids = selectedSubSkillIds
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        savedSubSkills = ids.sorted().joined(separator: ",")
    }

    private func toggleCategory(_ category: OnboardingCategory) {
        var ids = selectedSubSkillIds
        let subIds = category.subSkills.map(\.id)
        let allSelected = subIds.allSatisfy { ids.contains($0) }
        if allSelected {
            subIds.forEach { ids.remove($0) }
        } else {
            subIds.forEach { ids.insert($0) }
        }
        savedSubSkills = ids.sorted().joined(separator: ",")
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                Text("Tap a scene to select all its skills, or tap individual skills to customize.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                ForEach(SkillCategoryPresets.all) { category in
                    SystemCategoryRow(
                        category: category,
                        categoryState: categoryState(category),
                        isSubSkillSelected: isSubSkillSelected,
                        onToggleCategory: { toggleCategory(category) },
                        onToggleSubSkill: toggleSubSkill
                    )
                }
            }
            .padding(.bottom, 40)
        }
    }
}

private struct SystemCategoryRow: View {
    let category: OnboardingCategory
    let categoryState: Bool?        // true=all, false=none, nil=partial
    let isSubSkillSelected: (String) -> Bool
    let onToggleCategory: () -> Void
    let onToggleSubSkill: (String) -> Void

    var accentColor: Color {
        switch category.id {
        case "work_life":       return Color(hex: "#45B7D1")
        case "campus_life":     return Color(hex: "#A78BFA")
        case "relationships":   return Color(hex: "#F472B6")
        case "family":          return Color(hex: "#FB923C")
        case "personal_growth": return Color(hex: "#34D399")
        case "life_skills":     return Color(hex: "#FBBF24")
        default:                return Color(hex: "#5E7C8B")
        }
    }

    private var checkIcon: String {
        switch categoryState {
        case .some(true):  return "checkmark.circle.fill"
        case .some(false): return "circle"
        case .none:        return "minus.circle.fill"
        }
    }

    private var checkColor: Color {
        categoryState == false ? .white.opacity(0.3) : accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Category header row
            Button(action: onToggleCategory) {
                HStack(spacing: 10) {
                    Text(category.emoji)
                        .font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        let selCount = category.subSkills.filter { isSubSkillSelected($0.id) }.count
                        Text(selCount == 0 ? "\(category.subSkills.count) skills" : "\(selCount) / \(category.subSkills.count) selected")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(selCount == 0 ? .white.opacity(0.3) : accentColor.opacity(0.8))
                    }
                    Spacer()
                    Image(systemName: checkIcon)
                        .font(.system(size: 22))
                        .foregroundColor(checkColor)
                }
                .padding(.horizontal, 20)
            }
            .buttonStyle(.plain)

            // Sub-skill chips (tappable checkboxes)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(category.subSkills) { skill in
                        let selected = isSubSkillSelected(skill.id)
                        Button(action: { onToggleSubSkill(skill.id) }) {
                            HStack(spacing: 5) {
                                if selected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(accentColor)
                                }
                                Text(skill.name)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(selected ? accentColor : .white.opacity(0.55))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selected ? accentColor.opacity(0.15) : Color.white.opacity(0.07))
                                    .overlay(
                                        Capsule()
                                            .stroke(selected ? accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Custom Skill Tab

private enum CustomSkillStep {
    case form, previewing, preview, saving, done
}

private struct CustomSkillTab: View {
    @State private var step: CustomSkillStep = .form

    // Form inputs
    @State private var sceneText = ""
    @State private var purposeText = ""
    @State private var preferenceText = ""

    // Preview result
    @State private var previewName = ""
    @State private var previewDescription = ""
    @State private var previewMarkdown = ""

    // State
    @State private var errorMessage: String? = nil

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                stepContent
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 60)
        }
    }

    // MARK: Form

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .form:       formView
        case .previewing: loadingView("Generating skill with AI...")
        case .preview:    previewView
        case .saving:     loadingView("Saving...")
        case .done:       doneView
        }
    }

    private var formView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Describe a situation or skill you want to improve. AI will generate a personalized skill guide for you.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))

            // Scene (required)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Scene / Topic")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    Text("Required")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#45B7D1"))
                }
                TextField("e.g. Negotiating a raise with a nervous manager", text: $sceneText, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(12)
                    .tint(Color(hex: "#45B7D1"))
            }

            // Purpose (optional)
            VStack(alignment: .leading, spacing: 6) {
                Text("Your Goal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                TextField("e.g. Stay calm and get a yes without burning bridges", text: $purposeText, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(12)
                    .tint(Color(hex: "#45B7D1"))
            }

            // Preference (optional)
            VStack(alignment: .leading, spacing: 6) {
                Text("Style / Preference")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                TextField("e.g. Direct and concise, avoid long scripts", text: $preferenceText, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(12)
                    .tint(Color(hex: "#45B7D1"))
            }

            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 13))
                    .foregroundColor(.red.opacity(0.8))
            }

            Button(action: generatePreview) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Generate Skill")
                        .font(.system(size: 15, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(sceneText.trimmingCharacters(in: .whitespaces).isEmpty
                              ? Color.white.opacity(0.1)
                              : Color(hex: "#45B7D1"))
                )
                .foregroundColor(sceneText.trimmingCharacters(in: .whitespaces).isEmpty
                                 ? .white.opacity(0.3)
                                 : .white)
            }
            .buttonStyle(.plain)
            .disabled(sceneText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // MARK: Preview

    private var previewView: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SKILL NAME")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(1.2)
                Text(previewName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("DESCRIPTION")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(1.2)
                Text(previewDescription)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(3)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("FULL GUIDE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(1.2)
                Text(previewMarkdown)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .lineSpacing(4)
                    .padding(14)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
            }

            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 13))
                    .foregroundColor(.red.opacity(0.8))
            }

            HStack(spacing: 12) {
                Button(action: { step = .form }) {
                    Text("Regenerate")
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(13)
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)

                Button(action: saveSkill) {
                    Text("Add to Library")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color(hex: "#34D399"))
                        .cornerRadius(13)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Done

    private var doneView: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 40)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "#34D399"))
            Text("Skill Added!")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            Text("Your custom skill is now in your library and will be prioritized in future recordings.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Loading

    private func loadingView(_ message: String) -> some View {
        HStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
            Text(message)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: Actions

    private func generatePreview() {
        let scene = sceneText.trimmingCharacters(in: .whitespaces)
        guard !scene.isEmpty else { return }
        errorMessage = nil
        step = .previewing

        Task {
            do {
                let result = try await NetworkManager.shared.generateCustomSkillPreview(
                    scene: scene,
                    purpose: purposeText.trimmingCharacters(in: .whitespaces),
                    preference: preferenceText.trimmingCharacters(in: .whitespaces)
                )
                await MainActor.run {
                    previewName = result.name
                    previewDescription = result.description
                    previewMarkdown = result.markdown_content
                    step = .preview
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Generation failed. Please try again."
                    step = .form
                }
            }
        }
    }

    private func saveSkill() {
        errorMessage = nil
        step = .saving

        Task {
            do {
                _ = try await NetworkManager.shared.saveCustomSkill(
                    name: previewName,
                    description: previewDescription,
                    markdownContent: previewMarkdown,
                    sceneInput: sceneText,
                    purposeInput: purposeText,
                    preferenceInput: preferenceText
                )
                await MainActor.run {
                    step = .done
                    // Notify SkillsView to refresh custom skills
                    NotificationCenter.default.post(name: .customSkillsDidChange, object: nil)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Save failed. Please try again."
                    step = .preview
                }
            }
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let customSkillsDidChange = Notification.Name("customSkillsDidChange")
}
