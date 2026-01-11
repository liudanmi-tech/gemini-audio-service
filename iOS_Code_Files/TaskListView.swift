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
                            ForEach(viewModel.tasks) { task in
                                NavigationLink(destination: TaskDetailView(taskId: task.id)) {
                                    TaskCardView(task: task)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 0)
                    }
                    .refreshable {
                        viewModel.refreshTasks()
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
    }
}

// Header视图
struct HeaderView: View {
    var body: some View {
        HStack {
            Text("碎片")
                .font(AppFonts.headerTitle)
                .foregroundColor(AppColors.headerText)
            
            Spacer()
            
            Button(action: {
                // TODO: 添加按钮功能
            }) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 32))
                    .foregroundColor(AppColors.headerText)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 0)
        .background(AppColors.background.opacity(0.9))
    }
}


