//
//  ProfileListView.swift
//  WorkSurvivalGuide
//
//  档案列表视图 - 按照Figma设计稿实现
//

import SwiftUI

struct ProfileListView: View {
    @ObservedObject private var viewModel = ProfileViewModel.shared
    @State private var showingCreateProfile = false
    @State private var selectedProfile: Profile?
    
    var body: some View {
        ZStack {
            // 背景色已由 ContentView 提供
            
            VStack(spacing: 0) {
                // Header区域
                ProfileHeaderView(onAddTap: {
                    showingCreateProfile = true
                })
                
                // 主内容区域
                if viewModel.isLoading && viewModel.profiles.isEmpty {
                    Spacer()
                    ProgressView("加载中...")
                        .tint(AppColors.headerText)
                    Spacer()
                } else if viewModel.profiles.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(AppColors.secondaryText)
                        Text("还没有档案")
                            .font(AppFonts.cardTitle)
                            .foregroundColor(AppColors.secondaryText)
                        Text("点击右上角按钮创建档案")
                            .font(AppFonts.time)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 23.99053955078125) { // 根据Figma: gap 23.99px
                            // 会员计划卡片（可选，暂时不显示）
                            // MembershipCardView()
                            
                            // 档案列表
                            ForEach(viewModel.profiles) { profile in
                                ProfileCardView(profile: profile, onDelete: {
                                    Task {
                                        try? await viewModel.deleteProfile(profile.id)
                                        await MainActor.run {
                                            if selectedProfile?.id == profile.id { selectedProfile = nil }
                                        }
                                    }
                                })
                                    .padding(.horizontal, 19.992115020751953) // 根据Figma: padding horizontal 19.99px
                                    .onTapGesture {
                                        print("📋 [ProfileListView] 点击档案: \(profile.id)")
                                        selectedProfile = profile
                                        print("📋 [ProfileListView] selectedProfile 已设置: \(selectedProfile?.id ?? "nil")")
                                    }
                            }
                        }
                        .padding(.top, 0)
                        .padding(.bottom, 100) // 为底部导航栏留出空间
                    }
                }
            }
        }
        .onAppear {
            // 只在数据为空且不在加载中时才加载
            if viewModel.profiles.isEmpty && !viewModel.isLoading {
                viewModel.loadProfiles()
            }
        }
        .sheet(isPresented: $showingCreateProfile) {
            ProfileEditView(profile: nil)
        }
        .sheet(item: $selectedProfile) { profile in
            ProfileEditView(profile: profile)
        }
    }
}

// Header视图
struct ProfileHeaderView: View {
    let onAddTap: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // 左侧：标题
            Text("档案")
                .font(.system(size: 24, weight: .black, design: .rounded)) // Nunito 900, 24px
                .foregroundColor(AppColors.headerText) // #5E4B35
                .tracking(0.6) // letterSpacing 2.5% of 24px = 0.6pt
            
            Spacer()
            
            // 右侧：添加按钮
            Button(action: onAddTap) {
                ZStack {
                    Circle()
                        .fill(AppColors.headerText.opacity(0.1)) // rgba(94, 75, 53, 0.1)
                        .frame(width: 39.98, height: 39.98) // 根据Figma: 39.98 x 39.98px
                    
                    Image(systemName: "plus")
                        .font(.system(size: 19.99, weight: .bold))
                        .foregroundColor(AppColors.headerText)
                }
            }
        }
        .padding(.horizontal, 23.990530014038086) // 根据Figma: padding horizontal 23.99px
        .padding(.vertical, 0)
        .frame(height: 87.97) // 根据Figma: height 87.97px
        .background(Color(hex: "#F2E6D6").opacity(0.9)) // 根据Figma: rgba(242, 230, 214, 0.9)
    }
}

// 档案卡片视图
struct ProfileCardView: View {
    let profile: Profile
    var onDelete: (() -> Void)? = nil
    @ObservedObject private var audioPlayer = ProfileAudioPlayerService.shared
    @State private var showDeleteAlert = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
            // 照片、名称、关系区域
            VStack(alignment: .center, spacing: 0) {
                // 照片（圆形，带白色边框）
                if let photoUrl = profile.photoUrl {
                    if let url = URL(string: photoUrl) {
                        RemoteImageView(
                            url: url,
                            width: 95.99,
                            height: 95.99
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 3.448770046234131) // 根据Figma: strokeWeight 3.45px
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2) // 根据Figma: boxShadow
                    } else {
                        // URL格式不正确
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 95.99, height: 95.99)
                            .overlay(
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.red)
                                    .font(.system(size: 20))
                            )
                            .onAppear {
                                print("❌ [ProfileListView] URL格式不正确: \(photoUrl)")
                            }
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 3.448770046234131)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                    }
                } else {
                    // 默认头像
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 95.99, height: 95.99)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundColor(AppColors.secondaryText)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 3.448770046234131)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                }
                
                // 名称（居中）
                Text(profile.name)
                    .font(.system(size: 24, weight: .black, design: .rounded)) // Nunito 900, 24px
                    .foregroundColor(AppColors.headerText) // #5E4B35
                    .padding(.top, 111.99) // 根据Figma: 照片下方间距
                
                // 关系标签
                HStack(alignment: .center, spacing: 3.9984331130981445) { // 根据Figma: gap 3.99px
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#E68A00")) // 根据Figma: #E68A00
                    
                    Text(profile.relationship)
                        .font(.system(size: 12, weight: .bold, design: .rounded)) // Nunito 700, 12px
                        .foregroundColor(Color(hex: "#E68A00")) // #E68A00
                }
                .padding(.horizontal, 11.995254516601562) // 根据Figma: padding left 11.99px
                .padding(.vertical, 0)
                .frame(height: 23.99) // 根据Figma: height 23.99px
                .background(
                    Capsule()
                        .fill(Color(hex: "#FFD59E").opacity(0.3)) // rgba(255, 213, 158, 0.3)
                )
                .padding(.top, 4) // 根据Figma: 名称下方间距
                
                // 音频播放按钮和波形图
                if profile.audioUrl != nil || (profile.audioStartTime != nil && profile.audioEndTime != nil) {
                    HStack(alignment: .center, spacing: 11.995262145996094) { // 根据Figma: gap 11.99px
                        // 播放按钮（圆形）：有 audioUrl 时点击播放/暂停
                        Button(action: {
                            audioPlayer.togglePlayback(for: profile)
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#FFD59E")) // #FFD59E
                                    .frame(width: 39.99, height: 39.99)
                                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                                
                                Image(systemName: audioPlayer.currentPlayingProfileId == profile.id ? "pause.fill" : "play.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(AppColors.headerText)
                                    .offset(x: 1) // 稍微向右偏移，视觉居中
                            }
                        }
                        .disabled(profile.audioUrl == nil || !(profile.audioUrl?.hasPrefix("http") ?? false))
                        
                        // 时长和波形图
                        HStack(alignment: .center, spacing: 11.995264053344727) {
                            // 时长
                            if let startTime = profile.audioStartTime,
                               let endTime = profile.audioEndTime {
                                Text(formatDuration(endTime - startTime))
                                    .font(.system(size: 14, weight: .bold, design: .rounded)) // Nunito 700, 14px
                                    .foregroundColor(AppColors.headerText.opacity(0.8))
                            }
                            
                            // 波形图（简化版，使用多个小矩形）
                            HStack(alignment: .bottom, spacing: 1.9938182830810547) {
                                let heights: [CGFloat] = [3.19, 6.39, 9.59, 12.79, 9.59, 6.39, 3.19, 6.39, 9.59, 12.79, 9.59]
                                ForEach(0..<11) { index in
                                    RoundedRectangle(cornerRadius: 23144300)
                                        .fill(AppColors.headerText.opacity(0.6))
                                        .frame(
                                            width: 1.99,
                                            height: heights[index]
                                        )
                                }
                            }
                        }
                    }
                    .padding(.top, 4) // 关系标签下方间距
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 23.990509033203125) // 根据Figma: padding top 23.99px
            .padding(.horizontal, 23.990520477294922) // 根据Figma: padding horizontal 23.99px
            
            // 备注区域
            if let notes = profile.notes, !notes.isEmpty {
                HStack(alignment: .top, spacing: 11.995269775390625) { // 根据Figma: gap 11.99px
                    Image(systemName: "note.text")
                        .font(.system(size: 19.99))
                        .foregroundColor(AppColors.headerText.opacity(0.6))
                        .frame(width: 19.99, height: 19.99)
                    
                    VStack(alignment: .leading, spacing: 3.9983787536621094) { // 根据Figma: gap 3.99px
                        Text("备注")
                            .font(.system(size: 12, weight: .bold, design: .rounded)) // Nunito 700, 12px
                            .foregroundColor(AppColors.headerText.opacity(0.5)) // rgba(94, 75, 53, 0.5)
                        
                        Text(notes)
                            .font(.system(size: 14, weight: .medium, design: .rounded)) // Nunito 500, 14px
                            .foregroundColor(AppColors.headerText) // #5E4B35
                            .lineSpacing(22.75) // lineHeight 1.625em of 14px = 22.75px
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 15.99368667602539) // 根据Figma: padding horizontal 15.99px
                .padding(.vertical, 15.99371337890625) // 根据Figma: padding vertical 15.99px
                .padding(.top, 0)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "#F2E6D6").opacity(0.3)) // rgba(242, 230, 214, 0.3)
                )
                .padding(.top, 260.64 - 196.66 - 39.99) // 根据Figma计算间距
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 23.990509033203125) // 根据Figma: padding vertical 23.99px
        .background(Color(hex: "#FFFAF5")) // 根据Figma: #FFFAF5
        .cornerRadius(32) // 根据Figma: borderRadius 32px
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1) // 根据Figma: boxShadow
            
            // 档案删除按钮（卡片右上角）
            if let onDelete = onDelete {
                Button(action: { showDeleteAlert = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColors.headerText.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color(hex: "#F2E6D6").opacity(0.9)))
                }
                .padding(.top, 20)
                .padding(.trailing, 20)
            }
        }
        .alert("删除档案", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("确定删除「\(profile.name)」？删除后无法恢复。")
        }
    }
    
    // 格式化时长显示
    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "0:%02d", seconds)
        }
    }
}
