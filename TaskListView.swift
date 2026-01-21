import SwiftUI

struct TaskListView: View {
    @StateObject private var viewModel = TaskListViewModel()
    
    var body: some View {
        ZStack {
            // 背景色
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HeaderView()
                
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
                        LazyVStack(spacing: 16) {
                            // 按天分组显示（卡片间距 15.99px，四舍五入为 16px）
                            ForEach(Array(viewModel.groupedTasks.keys.sorted(by: >)), id: \.self) { dateKey in
                                VStack(alignment: .leading, spacing: 0) {
                                    // 该分组下的任务卡片
                                    ForEach(viewModel.groupedTasks[dateKey] ?? []) { task in
                                        NavigationLink(destination: TaskDetailView(taskId: task.id)) {
                                            TaskCardView(task: task)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .padding(.horizontal, 20)
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
            viewModel.loadTasks()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TaskUploaded"))) { _ in
            viewModel.refreshTasks()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NewTaskCreated"))) { _ in
            viewModel.refreshTasks()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TaskAnalysisCompleted"))) { _ in
            viewModel.refreshTasks()
        }
    }
}

// Header视图
struct HeaderView: View {
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("碎片")
                .font(AppFonts.headerTitle)
                .foregroundColor(AppColors.headerText)
            
            Spacer()
            
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
