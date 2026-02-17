//
//  TaskListView.swift
//  WorkSurvivalGuide
//
//  任务列表主视图 - 按照Figma设计稿精确实现
//

import SwiftUI

struct TaskListView: View {
    @ObservedObject private var viewModel = TaskListViewModel.shared
    @ObservedObject private var deviceManager = BluetoothDeviceManager.shared
    @State private var showDeviceSheet = false
    
    var body: some View {
        ZStack {
            // 背景色已由 ContentView 提供，这里不需要重复设置
            // AppColors.background
            //     .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header（含蓝牙设备按钮）
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
                        .background(AppColors.headerText.opacity(0.08))
                        .clipShape(Capsule())
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {}) {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 28))
                            .foregroundColor(AppColors.headerText)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AppColors.headerBackground)
                
                // 任务列表
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
                        LazyVStack(spacing: 30) { // 卡片间距改为 30 像素
                            // 按天分组显示
                            ForEach(Array(viewModel.groupedTasks.keys.sorted(by: >)), id: \.self) { dateKey in
                                VStack(alignment: .leading, spacing: 30) { // 同一天内多个卡片间距改为 30 像素
                                    // 该分组下的任务卡片
                                    ForEach(viewModel.groupedTasks[dateKey] ?? []) { task in
                                        TaskCardRow(task: task)
                                            .padding(.horizontal, 19.99) // 精确按照 Figma: padding: 0px 19.992115020751953px
                                    }
                                }
                            }
                        }
                        .padding(.top, 0)
                        .padding(.bottom, 100) // 为底部悬浮按钮留出空间
                    }
                    .refreshable {
                        await viewModel.refreshTasksAsync()
                    }
                }
            }
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
