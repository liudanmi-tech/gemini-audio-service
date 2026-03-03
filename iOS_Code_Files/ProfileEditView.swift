//
//  ProfileEditView.swift
//  WorkSurvivalGuide
//
//  档案编辑视图 - 创建/编辑档案
//

import SwiftUI
import PhotosUI
import UIKit

// MARK: - UITextField Wrapper
struct UITextFieldWrapper: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onCommit: (() -> Void)?
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.delegate = context.coordinator
        textField.borderStyle = .roundedRect
        textField.isUserInteractionEnabled = true
        textField.isEnabled = true
        textField.allowsEditingTextAttributes = true
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChange(_:)), for: .editingChanged)
        
        // 确保可以响应触摸
        textField.isMultipleTouchEnabled = false
        textField.isExclusiveTouch = true
        
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        // 只在文本真正不同且不是用户正在编辑时更新
        if uiView.text != text && !uiView.isFirstResponder {
            uiView.text = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: UITextFieldWrapper
        
        init(_ parent: UITextFieldWrapper) {
            self.parent = parent
        }
        
        @objc func textFieldDidChange(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onCommit?()
            return true
        }
    }
}

// MARK: - UITextView Wrapper
struct UITextViewWrapper: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.layer.borderColor = UIColor.gray.withAlphaComponent(0.3).cgColor
        textView.layer.borderWidth = 1
        textView.layer.cornerRadius = 8
        textView.isEditable = true
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.isUserInteractionEnabled = true
        textView.allowsEditingTextAttributes = true
        
        // 确保可以粘贴
        textView.pasteConfiguration = UIPasteConfiguration(forAccepting: NSString.self)
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // 只在文本真正不同且不是用户正在编辑时更新
        if uiView.text != text && !uiView.isFirstResponder {
            uiView.text = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: UITextViewWrapper
        
        init(_ parent: UITextViewWrapper) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            DispatchQueue.main.async {
                self.parent.text = textView.text
            }
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            return true
        }
    }
}

struct ProfileEditView: View {
    let profile: Profile?
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var viewModel = ProfileEditViewModel()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showingAudioSelection = false
    @FocusState private var focusedField: Field?
    @State private var nameText: String = ""
    @State private var notesText: String = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isUploadingPhoto = false
    @State private var photoUploadError: String?
    @State private var originalPhotoUrl: String? // 保存原始photoUrl，用于上传失败时恢复
    @State private var showUploadErrorAlert = false
    @State private var pendingSaveAction: (() -> Void)? // 待执行的保存操作
    
    enum Field {
        case name, notes
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 照片选择
                    VStack(spacing: 16) {
                        HStack {
                            Text("Profile Photo")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.headerText)
                            
                            if isUploadingPhoto {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Uploading...")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(AppColors.secondaryText)
                            } else if photoUploadError != nil {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 12))
                            }
                            
                            Spacer()
                        }
                        
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                if let image = selectedImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 3)
                                        )
                                } else if let photoUrl = Profile.getAccessiblePhotoURL(photoUrl: viewModel.photoUrl, baseURL: NetworkManager.shared.getBaseURL(), cacheBuster: profile.map { "\(Int($0.updatedAt.timeIntervalSince1970))" }), let url = URL(string: photoUrl) {
                                    RemoteImageView(
                                        url: url,
                                        width: 120,
                                        height: 120
                                    )
                                    .id(photoUrl)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 3)
                                    )
                                    .onAppear {
                                        print("📷 [ProfileEditView] RemoteImageView onAppear, photoUrl: \(photoUrl)")
                                    }
                                } else {
                                    ZStack {
                                        Circle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 120, height: 120)
                                        
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(AppColors.secondaryText)
                                    }
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 3)
                                    )
                                }
                            }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    // 名称输入
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.headerText)

                        TextField("Enter name", text: $nameText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 16, design: .rounded))
                            .focused($focusedField, equals: .name)
                            .onChange(of: nameText) { newValue in
                                viewModel.name = newValue
                            }
                    }
                    .padding(.horizontal, 24)
                    
                    // 关系选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Relationship")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.headerText)

                        Picker("Relationship", selection: $viewModel.relationship) {
                            ForEach(RelationshipType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.system(size: 16, design: .rounded))
                    }
                    .padding(.horizontal, 24)
                    
                    // 备注输入
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.headerText)

                        ZStack(alignment: .topLeading) {
                            // 背景
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .frame(minHeight: 100)
                            
                            // 占位符
                            if notesText.isEmpty {
                                Text("Enter notes")
                                    .font(.system(size: 16, design: .rounded))
                                    .foregroundColor(Color.gray.opacity(0.5))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 8)
                                    .allowsHitTesting(false)
                            }
                            
                            // TextEditor
                            TextEditor(text: $notesText)
                                .frame(minHeight: 100)
                                .font(.system(size: 16, design: .rounded))
                                .focused($focusedField, equals: .notes)
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .onChange(of: notesText) { newValue in
                                    viewModel.notes = newValue
                                }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // 音频选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Audio")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.headerText)
                        
                        Button(action: {
                            showingAudioSelection = true
                        }) {
                            HStack {
                                if let audioInfo = viewModel.audioInfo {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Audio selected")
                                            .font(.system(size: 14, design: .rounded))
                                            .foregroundColor(AppColors.headerText)
                                        Text(audioInfo)
                                            .font(.system(size: 12, design: .rounded))
                                            .foregroundColor(AppColors.secondaryText)
                                    }
                                } else {
                                    Text("Select from recordings")
                                        .font(.system(size: 14, design: .rounded))
                                        .foregroundColor(AppColors.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppColors.secondaryText)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // 保存按钮
                    Button(action: {
                        print("💾 [ProfileEditView] 点击保存按钮")
                        // 防止重复点击
                        guard !isSaving else {
                            print("⚠️ [ProfileEditView] 正在保存中，忽略重复点击")
                            return
                        }
                        
                        // 如果正在上传图片，不允许保存
                        if isUploadingPhoto {
                            print("⚠️ [ProfileEditView] 图片正在上传中，阻止保存")
                            errorMessage = "图片正在上传中，请等待上传完成后再保存\n\n上传完成后，保存按钮将自动可用"
                            showError = true
                            return
                        }
                        
                        // 如果图片上传失败，提示用户是否继续保存
                        if let uploadError = photoUploadError {
                            print("⚠️ [ProfileEditView] 图片上传失败，询问是否继续保存")
                            errorMessage = uploadError + "\n\n是否继续保存（保留原有头像）？"
                            showUploadErrorAlert = true
                            // 保存待执行的保存操作
                            pendingSaveAction = {
                                performSave()
                            }
                            return
                        }
                        
                        // 正常保存
                        print("✅ [ProfileEditView] 开始执行保存操作")
                        performSave()
                    }) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else if isUploadingPhoto {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(
                                isUploadingPhoto ? "Uploading image..." :
                                (profile == nil ? (isSaving ? "Creating..." : "Create") : (isSaving ? "Saving..." : "Save"))
                            )
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            isSaving || isUploadingPhoto ? Color.gray : Color.blue
                        )
                        .cornerRadius(12)
                    }
                    .disabled(isSaving || isUploadingPhoto)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .padding(.top, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(profile == nil ? "Create Profile" : "Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Save failed", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Image upload failed", isPresented: $showUploadErrorAlert) {
                Button("Cancel", role: .cancel) {
                    pendingSaveAction = nil
                }
                Button("Save anyway", role: .none) {
                    // 清除上传错误状态，恢复原始photoUrl
                    photoUploadError = nil
                    viewModel.photoUrl = originalPhotoUrl
                    // 执行保存
                    pendingSaveAction?()
                    pendingSaveAction = nil
                }
            } message: {
                Text(errorMessage)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        focusedField = nil
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
            .onChange(of: selectedPhoto) { newItem in
                Task {
                    // 保存原始photoUrl，用于上传失败时恢复
                    await MainActor.run {
                        originalPhotoUrl = viewModel.photoUrl
                        isUploadingPhoto = true
                        photoUploadError = nil
                    }
                    
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            selectedImage = image
                        }
                        
                        // 上传图片到服务器
                        do {
                            print("📤 [ProfileEditView] 开始上传图片... profileId=\(profile?.id ?? "新建")")
                            let photoUrl = try await NetworkManager.shared.uploadProfilePhoto(imageData: data, profileId: profile?.id)
                            await MainActor.run {
                                viewModel.photoUrl = photoUrl
                                isUploadingPhoto = false
                                photoUploadError = nil
                                print("✅ [ProfileEditView] 图片上传成功: \(photoUrl)")
                            }
                        } catch {
                            await MainActor.run {
                                // 上传失败，恢复原始photoUrl
                                viewModel.photoUrl = originalPhotoUrl
                                isUploadingPhoto = false
                                photoUploadError = "图片上传失败: \(error.localizedDescription)"
                                print("❌ [ProfileEditView] 图片上传失败: \(error)")
                                // 显示错误提示
                                errorMessage = photoUploadError ?? "图片上传失败"
                                showError = true
                            }
                        }
                    } else {
                        await MainActor.run {
                            isUploadingPhoto = false
                            photoUploadError = "无法加载图片"
                            errorMessage = photoUploadError ?? "无法加载图片"
                            showError = true
                        }
                    }
                }
            }
            .onAppear {
                print("📝 [ProfileEditView] onAppear, profile: \(profile?.id ?? "nil")")
                if let profile = profile {
                    print("📝 [ProfileEditView] 加载档案数据: \(profile.name)")
                    print("📝 [ProfileEditView] profile.photoUrl: \(profile.photoUrl ?? "nil")")
                    viewModel.loadFromProfile(profile)
                    nameText = viewModel.name
                    notesText = viewModel.notes
                    print("📝 [ProfileEditView] 数据已加载: name=\(viewModel.name), relationship=\(viewModel.relationship)")
                    print("📝 [ProfileEditView] viewModel.photoUrl: \(viewModel.photoUrl ?? "nil")")
                    if let photoUrl = viewModel.photoUrl {
                        print("📝 [ProfileEditView] 尝试创建URL: \(photoUrl)")
                        if let url = URL(string: photoUrl) {
                            print("📝 [ProfileEditView] URL创建成功: \(url)")
                        } else {
                            print("❌ [ProfileEditView] URL创建失败，photoUrl格式不正确")
                        }
                    }
                } else {
                    print("📝 [ProfileEditView] 创建新档案模式")
                    // 创建新档案时，重置所有字段
                    viewModel.name = ""
                    viewModel.relationship = RelationshipType.self_.rawValue
                    viewModel.notes = ""
                    nameText = ""
                    notesText = ""
                }
            }
            .sheet(isPresented: $showingAudioSelection) {
                AudioSelectionView(
                    selectedSessionId: $viewModel.audioSessionId,
                    selectedSegmentId: $viewModel.audioSegmentId,
                    selectedStartTime: $viewModel.audioStartTime,
                    selectedEndTime: $viewModel.audioEndTime,
                    selectedAudioUrl: $viewModel.audioUrl,
                    onSelectionComplete: { sessionId, segmentId, startTime, endTime, audioUrl in
                        viewModel.audioSessionId = sessionId
                        viewModel.audioSegmentId = segmentId
                        viewModel.audioStartTime = startTime
                        viewModel.audioEndTime = endTime
                        viewModel.audioUrl = audioUrl
                    }
                )
            }
        }
    }
    
    // 执行保存操作
    private func performSave() {
        print("💾 [ProfileEditView] performSave 开始执行")
        print("   isUploadingPhoto: \(isUploadingPhoto)")
        print("   photoUploadError: \(photoUploadError ?? "nil")")
        print("   viewModel.photoUrl: \(viewModel.photoUrl ?? "nil")")
        
        // 确保同步最新的输入值
        viewModel.name = nameText
        viewModel.notes = notesText
        focusedField = nil
        
        print("💾 [ProfileEditView] 同步后的数据:")
        print("   name: \(viewModel.name)")
        print("   relationship: \(viewModel.relationship)")
        print("   notes: \(viewModel.notes)")
        print("   photoUrl: \(viewModel.photoUrl ?? "nil")")
        
        isSaving = true
        
        Task {
            do {
                if let profile = profile {
                    // 更新档案
                    print("💾 [ProfileEditView] 开始更新档案: \(profile.id)")
                    var updatedProfile = profile
                    updatedProfile.name = viewModel.name
                    updatedProfile.relationship = viewModel.relationship
                    updatedProfile.notes = viewModel.notes
                    // 只有在photoUrl不为nil时才更新，避免覆盖原有头像
                    if let photoUrl = viewModel.photoUrl {
                        updatedProfile.photoUrl = photoUrl
                        print("💾 [ProfileEditView] 更新photoUrl: \(photoUrl)")
                    } else {
                        print("⚠️ [ProfileEditView] photoUrl为nil，保留原有头像")
                    }
                    updatedProfile.audioSessionId = viewModel.audioSessionId
                    updatedProfile.audioSegmentId = viewModel.audioSegmentId
                    updatedProfile.audioStartTime = viewModel.audioStartTime
                    updatedProfile.audioEndTime = viewModel.audioEndTime
                    updatedProfile.audioUrl = viewModel.audioUrl
                    
                    try await ProfileViewModel.shared.updateProfile(updatedProfile)
                    print("✅ [ProfileEditView] 档案更新成功")
                } else {
                    // 创建档案
                    print("💾 [ProfileEditView] 开始创建档案")
                    let newProfile = Profile(
                        id: UUID().uuidString,
                        name: viewModel.name,
                        relationship: viewModel.relationship,
                        photoUrl: viewModel.photoUrl,
                        notes: viewModel.notes,
                        audioSessionId: viewModel.audioSessionId,
                        audioSegmentId: viewModel.audioSegmentId,
                        audioStartTime: viewModel.audioStartTime,
                        audioEndTime: viewModel.audioEndTime,
                        audioUrl: viewModel.audioUrl,
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                    print("💾 [ProfileEditView] 创建档案数据:")
                    print("   id: \(newProfile.id)")
                    print("   name: \(newProfile.name)")
                    print("   photoUrl: \(newProfile.photoUrl ?? "nil")")
                    try await ProfileViewModel.shared.createProfile(newProfile)
                    print("✅ [ProfileEditView] 档案创建成功")
                }
                
                await MainActor.run {
                    // 刷新档案列表
                    ProfileViewModel.shared.loadProfiles(forceRefresh: true)
                    isSaving = false
                    print("📝 [ProfileEditView] 准备关闭页面")
                    // 延迟一点关闭，确保状态更新完成
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        print("📝 [ProfileEditView] 执行dismiss()")
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    print("❌ [ProfileEditView] 保存失败: \(error)")
                    print("   错误类型: \(type(of: error))")
                    print("   错误描述: \(error.localizedDescription)")
                    if let nsError = error as NSError? {
                        print("   错误代码: \(nsError.code)")
                        print("   错误域: \(nsError.domain)")
                        print("   用户信息: \(nsError.userInfo)")
                    }
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// 关系类型枚举
enum RelationshipType: String, CaseIterable {
    case self_ = "Self"
    case friend = "Best Friend"
    case leader = "Manager"
    case colleague = "Colleague"
    case family = "Family"
    case other = "Other"
}

// 档案编辑ViewModel
class ProfileEditViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var relationship: String = RelationshipType.self_.rawValue
    @Published var notes: String = ""
    @Published var photoUrl: String?
    @Published var audioSessionId: String?
    @Published var audioSegmentId: String?
    @Published var audioStartTime: Double?
    @Published var audioEndTime: Double?
    @Published var audioUrl: String?
    
    var audioInfo: String? {
        guard let sessionId = audioSessionId,
              let startTime = audioStartTime,
              let endTime = audioEndTime else {
            return nil
        }
        let duration = endTime - startTime
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "对话 \(sessionId.prefix(8))... | \(String(format: "%d:%02d", minutes, seconds))"
    }
    
    func loadFromProfile(_ profile: Profile) {
        name = profile.name
        relationship = profile.relationship
        notes = profile.notes ?? ""
        photoUrl = profile.photoUrl
        audioSessionId = profile.audioSessionId
        audioSegmentId = profile.audioSegmentId
        audioStartTime = profile.audioStartTime
        audioEndTime = profile.audioEndTime
        audioUrl = profile.audioUrl
    }
}
