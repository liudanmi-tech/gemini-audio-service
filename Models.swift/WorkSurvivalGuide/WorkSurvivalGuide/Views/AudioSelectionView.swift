//
//  AudioSelectionView.swift
//  WorkSurvivalGuide
//
//  音频选择视图 - 从对话记录中选择音频片段
//

import SwiftUI

struct AudioSelectionView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedSessionId: String?
    @Binding var selectedSegmentId: String?
    @Binding var selectedStartTime: Double?
    @Binding var selectedEndTime: Double?
    @Binding var selectedAudioUrl: String?
    let onSelectionComplete: (String?, String?, Double?, Double?, String?) -> Void
    
    @StateObject private var taskListViewModel = TaskListViewModel.shared
    @State private var selectedSession: TaskItem?
    @State private var selectedSpeaker: String?
    @State private var audioSegments: [AudioSegment] = []
    @State private var isLoadingSegments = false
    @State private var currentStep: SelectionStep = .session
    @State private var isExtractingSegment = false
    @State private var extractError: String?
    
    enum SelectionStep {
        case session    // 第一步：选择对话记录
        case speaker    // 第二步：选择说话人
        case segment    // 第三步：选择音频片段
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 步骤指示器
                    HStack(spacing: 8) {
                        StepIndicator(step: 1, isActive: currentStep == .session, isCompleted: currentStep != .session)
                        StepIndicator(step: 2, isActive: currentStep == .speaker, isCompleted: currentStep == .segment)
                        StepIndicator(step: 3, isActive: currentStep == .segment, isCompleted: false)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    // 内容区域
                    ScrollView {
                        VStack(spacing: 16) {
                            switch currentStep {
                            case .session:
                                // 第一步：选择对话记录
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("选择对话记录")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(AppColors.headerText)
                                        .padding(.horizontal, 24)
                                    
                                    ForEach(taskListViewModel.tasks.filter { $0.status == .archived }) { task in
                                        Button(action: {
                                            selectedSession = task
                                            currentStep = .speaker
                                            loadSpeakers(for: task)
                                        }) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(task.title)
                                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                                        .foregroundColor(AppColors.headerText)
                                                    
                                                    Text(formatTaskTime(task))
                                                        .font(.system(size: 14, design: .rounded))
                                                        .foregroundColor(AppColors.secondaryText)
                                                }
                                                
                                                Spacer()
                                                
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(AppColors.secondaryText)
                                            }
                                            .padding()
                                            .background(Color(hex: "#FFFAF5"))
                                            .cornerRadius(12)
                                        }
                                        .padding(.horizontal, 24)
                                    }
                                }
                                
                            case .speaker:
                                // 第二步：选择说话人
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("选择说话人")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(AppColors.headerText)
                                        .padding(.horizontal, 24)
                                    
                                    if isLoadingSegments {
                                        ProgressView("加载中...")
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                    } else {
                                        ForEach(Array(Set(audioSegments.map { $0.speaker })).sorted(), id: \.self) { speaker in
                                            Button(action: {
                                                selectedSpeaker = speaker
                                                currentStep = .segment
                                            }) {
                                                HStack {
                                                    Text(speaker)
                                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                                        .foregroundColor(AppColors.headerText)
                                                    
                                                    Spacer()
                                                    
                                                    Image(systemName: "chevron.right")
                                                        .font(.system(size: 14))
                                                        .foregroundColor(AppColors.secondaryText)
                                                }
                                                .padding()
                                                .background(Color(hex: "#FFFAF5"))
                                                .cornerRadius(12)
                                            }
                                            .padding(.horizontal, 24)
                                        }
                                    }
                                }
                                
                            case .segment:
                                // 第三步：选择音频片段
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("选择音频片段")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(AppColors.headerText)
                                        .padding(.horizontal, 24)
                                    
                                    ForEach(audioSegments.filter { $0.speaker == selectedSpeaker }) { segment in
                                        Button(action: {
                                            selectSegment(segment)
                                        }) {
                                            VStack(alignment: .leading, spacing: 8) {
                                                HStack {
                                                    Text(segment.content)
                                                        .font(.system(size: 14, design: .rounded))
                                                        .foregroundColor(AppColors.headerText)
                                                        .lineLimit(2)
                                                    
                                                    Spacer()
                                                    
                                                    Text(segment.durationString)
                                                        .font(.system(size: 12, design: .rounded))
                                                        .foregroundColor(AppColors.secondaryText)
                                                }
                                                
                                                Text("\(formatTime(segment.startTime)) - \(formatTime(segment.endTime))")
                                                    .font(.system(size: 12, design: .rounded))
                                                    .foregroundColor(AppColors.secondaryText)
                                            }
                                            .padding()
                                            .background(Color(hex: "#FFFAF5"))
                                            .cornerRadius(12)
                                        }
                                        .padding(.horizontal, 24)
                                        .disabled(isExtractingSegment)
                                    }
                                }
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
                if isExtractingSegment {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("正在提取音频...")
                        .tint(.white)
                        .scaleEffect(1.2)
                }
            }
            .navigationTitle("选择音频")
            .alert("提取失败", isPresented: Binding(
                get: { extractError != nil },
                set: { if !$0 { extractError = nil } }
            )) {
                Button("确定") { extractError = nil }
            } message: {
                if let msg = extractError { Text(msg) }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                if currentStep != .session {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("返回") {
                            if currentStep == .segment {
                                currentStep = .speaker
                            } else if currentStep == .speaker {
                                currentStep = .session
                                selectedSession = nil
                                selectedSpeaker = nil
                                audioSegments = []
                            }
                        }
                    }
                }
            }
            .onAppear {
                if taskListViewModel.tasks.isEmpty {
                    taskListViewModel.loadTasks()
                }
            }
        }
    }
    
    /// 选择片段：若尚无 audioUrl 则先调用后端提取，再回传并关闭
    private func selectSegment(_ segment: AudioSegment) {
        let hasValidUrl = segment.audioUrl.map { $0.hasPrefix("http") } ?? false
        if hasValidUrl, let url = segment.audioUrl {
            selectedSessionId = segment.sessionId
            selectedSegmentId = segment.id
            selectedStartTime = segment.startTime
            selectedEndTime = segment.endTime
            selectedAudioUrl = url
            onSelectionComplete(segment.sessionId, segment.id, segment.startTime, segment.endTime, url)
            presentationMode.wrappedValue.dismiss()
            return
        }
        isExtractingSegment = true
        extractError = nil
        Task {
            do {
                let response = try await NetworkManager.shared.extractAudioSegment(
                    sessionId: segment.sessionId,
                    startTime: segment.startTime,
                    endTime: segment.endTime,
                    speaker: segment.speaker
                )
                await MainActor.run {
                    selectedSessionId = segment.sessionId
                    selectedSegmentId = response.segmentId
                    selectedStartTime = segment.startTime
                    selectedEndTime = segment.endTime
                    selectedAudioUrl = response.audioUrl
                    onSelectionComplete(
                        segment.sessionId,
                        response.segmentId,
                        segment.startTime,
                        segment.endTime,
                        response.audioUrl
                    )
                    isExtractingSegment = false
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    isExtractingSegment = false
                    extractError = (error as NSError).localizedDescription
                }
            }
        }
    }
    
    // 加载说话人列表（从对话详情中提取）
    private func loadSpeakers(for task: TaskItem) {
        isLoadingSegments = true
        
        Task {
            do {
                // 优先使用API获取音频片段列表
                do {
                    let segmentsResponse = try await NetworkManager.shared.getAudioSegments(sessionId: task.id)
                    await MainActor.run {
                        audioSegments = segmentsResponse.segments
                        isLoadingSegments = false
                    }
                    return
                } catch {
                    print("⚠️ [AudioSelectionView] API获取音频片段失败，使用备用方案: \(error)")
                }
                
                // 备用方案：从对话详情中提取
                let detail = try await NetworkManager.shared.getTaskDetail(sessionId: task.id)
                
                // 从dialogues中提取音频片段
                var segments: [AudioSegment] = []
                
                for (index, dialogue) in detail.dialogues.enumerated() {
                    // 解析时间戳
                    let startTime = parseTimestamp(dialogue.timestamp ?? "00:00")
                    
                    // 计算结束时间（下一个对话的开始时间，或对话总时长）
                    let endTime: Double
                    if index < detail.dialogues.count - 1,
                       let nextTimestamp = detail.dialogues[index + 1].timestamp {
                        endTime = parseTimestamp(nextTimestamp)
                    } else {
                        endTime = Double(detail.duration)
                    }
                    
                    let duration = endTime - startTime
                    
                    let segment = AudioSegment(
                        id: "\(task.id)_\(index)",
                        sessionId: task.id,
                        speaker: dialogue.speaker,
                        startTime: startTime,
                        endTime: endTime,
                        duration: duration,
                        content: dialogue.content,
                        audioUrl: nil // 需要后端提取后才有URL
                    )
                    
                    segments.append(segment)
                }
                
                await MainActor.run {
                    audioSegments = segments
                    isLoadingSegments = false
                }
            } catch {
                print("❌ [AudioSelectionView] 加载对话详情失败: \(error)")
                await MainActor.run {
                    isLoadingSegments = false
                }
            }
        }
    }
    
    // 解析时间戳（格式："MM:SS"）为秒数
    private func parseTimestamp(_ timestamp: String) -> Double {
        let components = timestamp.split(separator: ":")
        if components.count == 2,
           let minutes = Double(components[0]),
           let seconds = Double(components[1]) {
            return minutes * 60 + seconds
        }
        return 0
    }
    
    // 格式化时间显示
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // 格式化任务时间显示
    private func formatTaskTime(_ task: TaskItem) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: task.startTime)
    }
}

// 步骤指示器
struct StepIndicator: View {
    let step: Int
    let isActive: Bool
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isActive || isCompleted ? Color.blue : Color.gray.opacity(0.3))
                .frame(width: 24, height: 24)
                .overlay(
                    Text(isCompleted ? "✓" : "\(step)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                )
            
            if step < 3 {
                Rectangle()
                    .fill(isCompleted ? Color.blue : Color.gray.opacity(0.3))
                    .frame(height: 2)
            }
        }
    }
}
