# Xcode 项目设置指南

## 📋 已创建的文件列表

所有代码文件已创建在项目根目录，现在需要将它们添加到 Xcode 项目中：

### 1. 数据模型（Models）
- ✅ `Models.swift/File.swift` - 已存在（包含 Task 和 APIResponse）

### 2. 网络服务（Services）
- `NetworkManager.swift` - 网络请求管理器
- `AudioRecorderService.swift` - 录音服务

### 3. ViewModel
- `TaskListViewModel.swift` - 任务列表 ViewModel
- `RecordingViewModel.swift` - 录音 ViewModel

### 4. 视图组件（Views）
- `TaskCardView.swift` - 任务卡片组件
- `RecordingButtonView.swift` - 录制按钮组件
- `TaskListView.swift` - 任务列表主视图
- `TaskDetailView.swift` - 任务详情视图

### 5. 主视图
- `ContentView_Updated.swift` - 更新后的 ContentView（需要替换原有的 ContentView.swift）

---

## 🚀 在 Xcode 中添加文件的步骤

### 步骤 1: 创建文件夹结构（可选，但推荐）

1. 在 Xcode 项目导航器中，右键点击 `WorkSurvivalGuide` 文件夹（蓝色图标）
2. 选择 **New Group**，创建以下文件夹：
   ```
   WorkSurvivalGuide/
   ├── Services/
   ├── ViewModels/
   └── Views/
   ```

### 步骤 2: 添加文件到项目

对于每个 `.swift` 文件，执行以下操作：

1. **在 Finder 中找到文件**
   - 文件位置：`/Users/liudan/Desktop/AI军师/gemini-audio-service/`
   - 找到对应的 `.swift` 文件

2. **拖拽到 Xcode**
   - 将文件从 Finder 拖拽到 Xcode 项目导航器的对应文件夹中
   - 或者右键点击文件夹 → **Add Files to "WorkSurvivalGuide"...**
   - 选择文件，确保勾选 **"Copy items if needed"** 和 **"Add to targets: WorkSurvivalGuide"**
   - 点击 **Add**

3. **按顺序添加以下文件**：

   **Services 文件夹**：
   - `NetworkManager.swift`
   - `AudioRecorderService.swift`

   **ViewModels 文件夹**：
   - `TaskListViewModel.swift`
   - `RecordingViewModel.swift`

   **Views 文件夹**：
   - `TaskCardView.swift`
   - `RecordingButtonView.swift`
   - `TaskListView.swift`
   - `TaskDetailView.swift`

### 步骤 3: 更新 ContentView

1. 打开项目中的 `ContentView.swift` 文件
2. 用 `ContentView_Updated.swift` 的内容替换它
3. 或者直接复制 `ContentView_Updated.swift` 的内容到 `ContentView.swift`

---

## ⚙️ 配置项目

### 1. 添加 Alamofire 依赖

1. 在项目导航器中，点击项目名称（蓝色图标）
2. 选择 **WorkSurvivalGuide** target
3. 点击顶部的 **Package Dependencies** 标签
4. 点击左下角的 **+** 按钮
5. 输入：`https://github.com/Alamofire/Alamofire.git`
6. 选择版本：**Up to Next Major Version**，输入 `5.8.0`
7. 点击 **Add Package**
8. 确保 **Alamofire** 被勾选
9. 点击 **Add Package**

### 2. 配置麦克风权限

1. 在项目导航器中，找到 `Info.plist` 文件
2. 打开它
3. 添加一行：
   - **Key**: `Privacy - Microphone Usage Description`
   - **Value**: `需要访问麦克风以录制会议音频`

### 3. 设置部署目标

1. 点击项目名称（蓝色图标）
2. 选择 **WorkSurvivalGuide** target
3. 在 **General** 标签页，找到 **Deployment Info**
4. 将 **iOS** 设置为 **16.0**

### 4. 配置 API 地址

1. 打开 `NetworkManager.swift` 文件
2. 找到这一行：
   ```swift
   private let baseURL = "http://localhost:8001/api/v1"
   ```
3. 根据你的后端地址修改：
   - 如果后端在本地运行：`http://localhost:8001/api/v1`
   - 如果后端在服务器：`http://your-server-ip:8001/api/v1`
   - 如果使用 HTTPS：`https://your-domain.com/api/v1`

---

## ✅ 验证设置

### 检查文件是否正确添加

1. 在项目导航器中，所有文件应该显示为蓝色图标
2. 如果文件是红色，说明文件路径有问题，需要重新添加

### 检查编译

1. 按 `Cmd + B` 编译项目
2. 查看是否有错误：
   - 如果提示找不到 `Alamofire`，说明依赖没有正确添加
   - 如果提示找不到某个类，说明文件没有正确添加到项目中

---

## 🎯 运行项目

1. **选择模拟器**
   - 在 Xcode 顶部工具栏，点击设备选择器
   - 选择 **iPhone 15 Pro** 或任意 iOS 16+ 模拟器

2. **运行项目**
   - 点击左上角的 **▶** 按钮
   - 或按 `Cmd + R`

3. **首次运行**
   - 模拟器会自动启动
   - 如果提示麦克风权限，点击 **Allow**

---

## 🐛 常见问题

### 问题 1: 编译错误 "Cannot find 'Alamofire'"
**解决方案**：
- 检查 Alamofire 是否正确添加到 Package Dependencies
- 尝试：`File` → `Packages` → `Reset Package Caches`
- 重新编译项目

### 问题 2: 文件显示为红色
**解决方案**：
- 文件路径丢失，需要重新添加文件
- 右键点击红色文件 → `Delete`（选择 Remove Reference）
- 重新添加文件

### 问题 3: 运行时崩溃
**解决方案**：
- 查看 Xcode 底部的控制台输出
- 检查错误信息
- 确保所有文件都已添加到项目中

### 问题 4: 麦克风权限被拒绝
**解决方案**：
- 在模拟器中：`Settings` → `Privacy` → `Microphone` → 开启权限
- 在真机上：`Settings` → `WorkSurvivalGuide` → `Microphone` → 开启权限

### 问题 5: 网络请求失败
**解决方案**：
- 检查 `NetworkManager.swift` 中的 `baseURL` 是否正确
- 确保后端服务正在运行
- 检查网络连接

---

## 📝 下一步

完成基础设置后，可以：
1. 测试录音功能
2. 测试任务列表加载
3. 测试文件上传
4. 继续开发任务详情页的完整功能

---

**提示**: 如果遇到任何问题，请查看 Xcode 的控制台输出，那里会显示详细的错误信息。

