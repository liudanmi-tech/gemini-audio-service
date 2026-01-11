# iOS 代码文件说明

## 📁 文件列表

这些是 iOS 客户端的所有代码文件，按照以下顺序添加到 Xcode 项目中：

### 1. 数据模型（Models）
- `Task.swift` - 任务数据模型
- `APIResponse.swift` - API 响应模型

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
- `TaskDetailView.swift` - 任务详情视图（简化版）

### 5. 主视图
- `ContentView.swift` - 主 TabView

## 🚀 使用步骤

1. **在 Xcode 中创建项目**（参考 iOS_QUICK_START.md）

2. **创建文件夹结构**：
   ```
   WorkSurvivalGuide/
   ├── TaskModule/
   │   ├── Views/
   │   ├── ViewModels/
   │   ├── Models/
   │   └── Services/
   └── Shared/
       └── Models/
   ```

3. **逐个创建文件并复制代码**：
   - 右键点击对应文件夹 → `New File...` → `Swift File`
   - 复制对应文件的代码

4. **重要配置**：
   - 在 `NetworkManager.swift` 中修改 `baseURL` 为你的后端地址
   - 确保 `Info.plist` 中添加了麦克风权限说明

5. **运行项目**：
   - 选择模拟器
   - 点击 ▶ 运行

## ⚠️ 注意事项

- 所有文件都需要添加到项目中（项目导航器中应该有蓝色图标）
- 确保 Alamofire 已正确安装
- 首次运行需要在模拟器中允许麦克风权限

## 📝 下一步

完成基础功能后，可以继续实现：
- 任务详情页的完整功能
- 对话段落展示
- 策略建议显示
- 焚毁功能


