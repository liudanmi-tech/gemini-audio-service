//
//  TaskListView.swift
//  WorkSurvivalGuide
//
//  任务列表主视图 - 按照Figma设计稿精确实现
//

import SwiftUI

// 用于追踪滚动内容顶部在屏幕上的 Y 坐标
private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 999
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next < value { value = next }
    }
}

struct TaskListView: View {
    @ObservedObject private var viewModel = TaskListViewModel.shared
    @ObservedObject private var deviceManager = BluetoothDeviceManager.shared
    @State private var showDeviceSheet = false
    @State private var scrollOffset: CGFloat = 999
    
    /// 是否已上滑（卡片上边缘接触到顶部区域后再切换为毛玻璃）
    /// 内容顶部 global minY < 0 表示卡片已滑入 header 下方
    private var hasScrolledUp: Bool {
        scrollOffset < 0
    }
    
    /// 顶部 Header 毛玻璃背景（与卡片文字蒙层一致：ultraThinMaterial + black 0.25）
    @ViewBuilder
    private var headerFrostedGlassBackground: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(
                Color.black.opacity(0.25)
            )
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // 主内容区（全屏，滚动时内容可从 Header 下方通过）
            VStack(spacing: 0) {
                if viewModel.isLoading && viewModel.tasks.isEmpty {
                    Spacer()
                    ProgressView("加载中...")
                        .tint(AppColors.headerText)
                    Spacer()
                } else if viewModel.tasks.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "mic.slash")
                            .font(.system(size: 50))
                            .foregroundColor(AppColors.secondaryText)
                        Text("还没有任务")
                            .font(AppFonts.cardTitle)
                            .foregroundColor(AppColors.secondaryText)
                        Text("点击下方按钮开始录音")
                            .font(AppFonts.time)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            // 按天分组显示
                            ForEach(Array(viewModel.groupedTasks.keys.sorted(by: >)), id: \.self) { dateKey in
                                VStack(alignment: .leading, spacing: 12) {
                                    // 日期分组标题
                                    Text(viewModel.groupTitle(for: dateKey))
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(AppColors.headerText.opacity(0.7))
                                        .padding(.horizontal, 4)
                                    
                                    // 单列布局
                                    VStack(spacing: 12) {
                                        ForEach(viewModel.groupedTasks[dateKey] ?? []) { task in
                                            TaskCardRow(task: task)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 50) // 与 Header 高度匹配
                        .padding(.bottom, 100) // 为底部悬浮按钮留出空间
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: geo.frame(in: .global).minY
                                )
                            }
                        )
                    }
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        scrollOffset = value
                    }
                    .refreshable {
                        await viewModel.refreshTasksAsync()
                    }
                }
            }
            
            // 顶部 Header 覆盖层（使用与 BottomNavView 相同参数的毛玻璃）
            HStack(alignment: .center, spacing: 0) {
                Text("碎片")
                    .font(AppFonts.headerTitle)
                    .foregroundColor(AppColors.headerText)
                
                Spacer()
                
                Button(action: { showDeviceSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 20, weight: .medium))
                        Text("设备")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(deviceManager.isBluetoothConnected ? Color.blue : AppColors.headerText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Capsule())
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Button(action: {}) {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.headerText)
                        .frame(width: 36, height: 36)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)  // 顶部高度约 52pt（8+36+8，不含状态栏）
            .background(
                Group {
                    if hasScrolledUp {
                        headerFrostedGlassBackground
                    } else {
                        Color.black
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: hasScrolledUp)
                .ignoresSafeArea(edges: .top)  // 延伸到状态栏下方，防止顶部漏出下层卡片
            )
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .onAppear {
            // 只在数据为空且不在加载中时才加载
            if viewModel.tasks.isEmpty && !viewModel.isLoading {
                viewModel.loadTasks()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TaskUploaded"))) { _ in
            viewModel.refreshTasks()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NewTaskCreated"))) { notification in
            if let task = notification.object as? TaskItem {
                viewModel.addNewTask(task)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TaskAnalysisCompleted"))) { notification in
            if let task = notification.object as? TaskItem {
                viewModel.updateTask(task)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TaskStatusUpdated"))) { notification in
            if let task = notification.object as? TaskItem {
                viewModel.updateTaskStatus(task)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TaskDeleted"))) { notification in
            if let taskId = notification.object as? String {
                viewModel.deleteTask(taskId: taskId)
            }
        }
        .sheet(isPresented: $showDeviceSheet) {
            DeviceSelectionSheet()
        }
    }
}

// 任务卡片行（用于简化复杂表达式）
struct TaskCardRow: View {
    let task: TaskItem
    
    var body: some View {
        // 只有在已完成状态才能进入详情页
        if task.status == .archived {
            NavigationLink(destination: TaskDetailView(task: task)) {
                TaskCardView(task: task)
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            // 录制中或分析中状态，不能点击进入详情页
            TaskCardView(task: task)
                .opacity(0.9) // 稍微降低透明度表示不可点击
        }
    }
}

// Header视图
struct HeaderView: View {
    var isBluetoothConnected: Bool = false
    var onDeviceTap: () -> Void = {}
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("碎片")
                .font(AppFonts.headerTitle)
                .foregroundColor(AppColors.headerText)
            
            Spacer()
            
            // 设备按钮（蓝牙录音）
            Button(action: onDeviceTap) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 24))
                    .foregroundColor(isBluetoothConnected ? Color.blue : AppColors.headerText)
                    .frame(width: 44, height: 44)
            }
            
            Button(action: {
                // TODO: 添加更多功能菜单
            }) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 28))
                    .foregroundColor(AppColors.headerText)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(AppColors.headerBackground)
    }
}
