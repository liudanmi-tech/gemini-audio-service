# iOS 项目检查清单

## ✅ 文件完整性检查

请确认以下所有文件都已创建并添加到 Xcode 项目中：

### 1. 数据模型（Models）
- [x] `Models.swift/File.swift` - 包含 Task、APIResponse、TaskListResponse、UploadResponse
- [ ] 确认文件在项目导航器中显示（应该有蓝色图标）

### 2. 网络服务（Services）
- [x] `NetworkManager.swift` - 网络请求管理器
- [x] `AudioRecorderService.swift` - 录音服务
- [ ] 确认文件在项目导航器中显示

### 3. ViewModel
- [x] `TaskListViewModel.swift` - 任务列表 ViewModel
- [x] `RecordingViewModel.swift` - 录音 ViewModel
- [ ] 确认文件在项目导航器中显示

### 4. 视图组件（Views）
- [x] `TaskCardView.swift` - 任务卡片组件
- [x] `RecordingButtonView.swift` - 录制按钮组件
- [x] `TaskListView.swift` - 任务列表主视图
- [x] `TaskDetailView.swift` - 任务详情视图
- [ ] 确认文件在项目导航器中显示

### 5. 主视图
- [x] `ContentView.swift` 或 `ContentView_Updated.swift` - 主 TabView
- [ ] 确认文件在项目导航器中显示

---

## ⚙️ 项目配置检查

### 1. 项目设置
- [ ] **Deployment Target** 设置为 `iOS 16.0`
  - 路径：项目名称 → Target → General → Deployment Info → iOS

### 2. 权限配置
- [ ] **Info.plist** 中添加了麦克风权限说明
  - Key: `Privacy - Microphone Usage Description`
  - Value: `需要访问麦克风以录制会议音频`

### 3. 第三方库
- [ ] **Alamofire** 已添加
  - 路径：项目名称 → Package Dependencies
  - 确认 Alamofire 显示在列表中

### 4. API 地址配置
- [ ] **NetworkManager.swift** 中的 `baseURL` 已修改
  ```swift
  private let baseURL = "http://localhost:8001/api/v1"
  ```
  - 如果后端在本地：`http://localhost:8001/api/v1`
  - 如果后端在服务器：`http://your-server-ip:8001/api/v1`

---

## 🔧 常见问题修复

### 问题 1: 编译错误 - "Cannot find type 'Task'"
**原因**: 文件没有正确添加到项目中

**解决方法**:
1. 在项目导航器中，右键点击 `Models.swift` 文件夹
2. 选择 `Add Files to "WorkSurvivalGuide"...`
3. 选择 `File.swift` 文件
4. 确保 `Copy items if needed` 和 `Add to targets: WorkSurvivalGuide` 都被勾选
5. 点击 `Add`

### 问题 2: 编译错误 - "No such module 'Alamofire'"
**原因**: Alamofire 没有正确安装

**解决方法**:
1. 点击项目名称 → `Package Dependencies` 标签
2. 点击左下角的 `+` 按钮
3. 输入：`https://github.com/Alamofire/Alamofire.git`
4. 选择版本 `5.8.0` → `Add Package`
5. 等待下载完成

### 问题 3: 运行时错误 - 麦克风权限被拒绝
**解决方法**:
- **模拟器**: `Settings` → `Privacy` → `Microphone` → 开启权限
- **真机**: `Settings` → `WorkSurvivalGuide` → `Microphone` → 开启权限

### 问题 4: 网络请求失败
**检查项**:
1. 确认后端服务正在运行
2. 确认 `baseURL` 地址正确
3. 如果使用模拟器访问本地服务器，使用 `http://localhost:8001`
4. 如果使用真机访问本地服务器，使用 Mac 的 IP 地址（如 `http://192.168.1.100:8001`）

---

## 🚀 运行测试步骤

### 步骤 1: 清理项目
1. 在 Xcode 中，选择 `Product` → `Clean Build Folder` (或按 `Shift + Cmd + K`)

### 步骤 2: 选择模拟器
1. 在顶部工具栏，点击设备选择器
2. 选择 **iPhone 15 Pro** 或任意 iOS 16+ 模拟器

### 步骤 3: 运行项目
1. 点击左上角的 **▶** 按钮（或按 `Cmd + R`）
2. 等待编译完成（第一次可能需要几分钟）
3. 模拟器会自动启动并运行 APP

### 步骤 4: 测试功能
1. **测试录音功能**:
   - 点击底部的红色录制按钮
   - 应该会弹出麦克风权限请求
   - 点击"允许"
   - 按钮应该开始闪烁，显示录音时长
   - 再次点击停止录音

2. **测试任务列表**:
   - 如果后端 API 已配置，应该能看到任务列表
   - 如果没有后端，会显示"还没有任务"
   - 下拉可以刷新列表

---

## 📝 下一步开发

完成基础功能后，可以继续实现：

1. **任务详情页完整功能**
   - 对话段落展示
   - 策略建议显示
   - 人物筛选

2. **优化功能**
   - 下拉刷新优化
   - 加载状态提示
   - 错误提示优化

3. **其他模块**
   - 状态模块（老黄牛 Avatar）
   - 档案模块（说话人管理）

---

## 🆘 获取帮助

如果遇到问题：

1. **查看 Xcode 控制台**
   - 底部面板会显示详细的错误信息
   - 红色错误信息会指出具体问题

2. **检查文件是否正确添加**
   - 在项目导航器中，所有文件应该有蓝色图标
   - 如果文件是灰色，说明没有添加到项目中

3. **查看编译错误**
   - 点击红色错误标记，Xcode 会显示具体问题
   - 按照提示修复问题

---

**提示**: 如果所有文件都已创建但仍有编译错误，请检查文件是否都正确添加到项目中（项目导航器中应该有蓝色图标）。


