import SwiftUI

// 技能信息视图
struct SkillInfoView: View {
    let appliedSkills: [AppliedSkill]
    let sceneCategory: String?
    let sceneConfidence: Double?
    
    @State private var selectedSkill: AppliedSkill?
    @State private var skillDetail: SkillDetailResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 场景信息
            if let category = sceneCategory {
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundColor(.blue)
                    Text("场景类别")
                        .font(.headline)
                    Spacer()
                    Text(category)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(10)
            }
            
            // 置信度
            if let confidence = sceneConfidence {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.green)
                    Text("场景置信度")
                        .font(.headline)
                    Spacer()
                    Text(String(format: "%.0f%%", confidence * 100))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(10)
            }
            
            // 应用的技能列表
            if !appliedSkills.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                        Text("应用的技能")
                            .font(.headline)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    ForEach(appliedSkills) { skill in
                        SkillCardView(
                            skill: skill,
                            onTap: {
                                loadSkillDetail(skillId: skill.skillId)
                            }
                        )
                    }
                }
                .padding(.vertical, 8)
            }
            
            // 技能详情（展开时显示）
            if let skillDetail = skillDetail {
                SkillDetailContentView(skillDetail: skillDetail)
                    .padding(.top, 8)
            }
            
            // 错误信息
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
        }
        .padding()
    }
    
    private func loadSkillDetail(skillId: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let detail = try await NetworkManager.shared.getSkillDetail(skillId: skillId, includeContent: true)
                await MainActor.run {
                    skillDetail = detail
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "加载技能详情失败: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

// 技能卡片视图
struct SkillCardView: View {
    let skill: AppliedSkill
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(skill.skillId)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if let confidence = skill.confidence {
                        Text("置信度: \(String(format: "%.0f%%", confidence * 100))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("优先级: \(skill.priority)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 技能详情内容视图
struct SkillDetailContentView: View {
    let skillDetail: SkillDetailResponse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 技能基本信息
            VStack(alignment: .leading, spacing: 8) {
                Text(skillDetail.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let description = skillDetail.description {
                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label(skillDetail.category, systemImage: "folder.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    if let version = skillDetail.version {
                        Label("v\(version)", systemImage: "tag.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(10)
            
            // SKILL.md 内容
            if let content = skillDetail.content {
                VStack(alignment: .leading, spacing: 8) {
                    Text("技能文档")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView {
                        Text(content)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                    }
                    .frame(maxHeight: 400)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
