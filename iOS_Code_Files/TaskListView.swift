import SwiftUI

struct TaskListView: View {
    @StateObject private var viewModel = TaskListViewModel()
    @StateObject private var recordingViewModel = RecordingViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                // 任务列表
                if viewModel.isLoading && viewModel.tasks.isEmpty {
                    ProgressView("加载中...")
                } else if viewModel.tasks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "mic.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("还没有任务")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("点击下方按钮开始录音")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // 按天分组显示
                            ForEach(Array(viewModel.groupedTasks.keys.sorted(by: >)), id: \.self) { dateKey in
                                Section {
                                    ForEach(viewModel.groupedTasks[dateKey] ?? []) { task in
                                        NavigationLink(destination: TaskDetailView(taskId: task.id)) {
                                            TaskCardView(task: task)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                } header: {
                                    HStack {
                                        Text(viewModel.groupTitle(for: dateKey))
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                }
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        viewModel.refreshTasks()
                    }
                }
                
                // 悬浮录制按钮
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        RecordingButtonView(viewModel: recordingViewModel)
                            .padding(.trailing, 20)
                            .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("任务 (副本)")
            .onAppear {
                viewModel.loadTasks()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TaskUploaded"))) { _ in
                // 任务上传成功后刷新列表
                viewModel.refreshTasks()
            }
        }
    }
}


