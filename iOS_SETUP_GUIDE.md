# iOS 项目完整设置指南

## 📋 第一步：确认文件结构

在 Xcode 项目导航器中，你的文件结构应该是这样的：

```
WorkSurvivalGuide/
├── WorkSurvivalGuideApp.swift (自动生成)
├── ContentView.swift (或 ContentView_Updated.swift)
│
├── Models.swift/
│   └── File.swift (包含 Task、APIResponse 等)
│
├── NetworkManager.swift
├── AudioRecorderService.swift
│
├── TaskListViewModel.swift
├── RecordingViewModel.swift
│
├── TaskListView.swift
├── TaskCardView.swift
├── RecordingButtonView.swift
├── TaskDetailView.swift
│
└── Info.plist
```

---

## 🔧 第二步：确保文件已添加到项目

### 检查方法
1. 在项目导航器中，查看每个文件
2. **蓝色图标** ✅ = 文件已添加到项目
3. **灰色图标** ❌ = 文件未添加到项目

### 如果文件是灰色的，需要添加：

1. **右键点击文件** → `Delete` → 选择 `Remove Reference`（不要选择 `Move to Trash`）

2. **重新添加文件**:
   - 右键点击项目文件夹（蓝色图标）
   - 选择 `Add Files to "WorkSurvivalGuide"...`
   - 选择文件
   - **重要**: 确保勾选：
     - ✅ `Copy items if needed`
     - ✅ `Add to targets: WorkSurvivalGuide`
   - 点击 `Add`

---

## ⚙️ 第三步：配置项目设置

### 1. 设置 Deployment Target

1. 点击项目名称（蓝色图标，最顶部）
2. 选择 **WorkSurvivalGuide** target（在 TARGETS 下）
3. 点击 **General** 标签
4. 找到 **Deployment Info**
5. 将 **iOS** 设置为 **16.0**

### 2. 添加麦克风权限

1. 在项目导航器中找到 `Info.plist`
2. 右键点击空白处 → `Add Row`
3. 在 **Key** 列输入：`Privacy - Microphone Usage Description`
4. 在 **Value** 列输入：`需要访问麦克风以录制会议音频`

**或者** 在代码中添加（推荐）：
1. 打开 `Info.plist` 作为源代码（右键 → `Open As` → `Source Code`）
2. 在 `<dict>` 标签内添加：
```xml
<key>NSMicrophoneUsageDescription</key>
<string>需要访问麦克风以录制会议音频</string>
```

---

## 📦 第四步：添加 Alamofire 依赖

### 如果还没有添加：

1. 点击项目名称（蓝色图标）
2. 选择 **WorkSurvivalGuide** target
3. 点击顶部的 **Package Dependencies** 标签
4. 点击左下角的 **+** 按钮
5. 在搜索框输入：`https://github.com/Alamofire/Alamofire.git`
6. 点击 **Add Package**
7. 选择版本：**Up to Next Major Version**，输入 `5.8.0`
8. 点击 **Add Package**
9. 在下一个界面，确保 **Alamofire** 被勾选
10. 点击 **Add Package**
11. 等待下载完成（可能需要几分钟）

### 验证安装：
- 在 `Package Dependencies` 标签中，应该能看到 Alamofire
- 在代码中输入 `import Alamofire` 不应该报错

---

## 🌐 第五步：配置 API 地址

1. 打开 `NetworkManager.swift`
2. 找到这一行：
```swift
private let baseURL = "http://localhost:8001/api/v1"
```

3. **根据你的情况修改**：

   **情况 A: 后端运行在本地 Mac**
   ```swift
   private let baseURL = "http://localhost:8001/api/v1"
   ```

   **情况 B: 后端运行在服务器**
   ```swift
   private let baseURL = "http://your-server-ip:8001/api/v1"
   ```
   替换 `your-server-ip` 为实际 IP 地址

   **情况 C: 使用模拟器访问本地服务器**
   - 如果后端在 Mac 上运行，模拟器可以使用 `localhost`
   - 如果后端在其他机器，使用该机器的 IP 地址

   **情况 D: 使用真机访问本地服务器**
   - 不能使用 `localhost`，必须使用 Mac 的 IP 地址
   - 查找 Mac IP 地址：`系统设置` → `网络` → 查看 IP 地址
   - 例如：`http://192.168.1.100:8001/api/v1`

---

## ✅ 第六步：验证设置

### 编译检查
1. 按 `Cmd + B` 编译项目
2. 查看是否有错误
3. 如果有错误，按照错误提示修复

### 常见编译错误修复：

**错误 1: "Cannot find type 'Task'"**
- 检查 `Models.swift/File.swift` 是否已添加到项目
- 确保文件在项目导航器中有蓝色图标

**错误 2: "No such module 'Alamofire'"**
- 重新添加 Alamofire 依赖（见第四步）

**错误 3: "Use of unresolved identifier"**
- 检查文件是否都正确导入
- 确保所有文件都在项目中

---

## 🚀 第七步：运行项目

1. **选择模拟器**
   - 在顶部工具栏，点击设备选择器
   - 选择 **iPhone 15 Pro** 或任意 iOS 16+ 模拟器

2. **运行项目**
   - 点击左上角的 **▶** 按钮
   - 或按 `Cmd + R`

3. **等待编译和启动**
   - 第一次编译可能需要几分钟
   - 模拟器会自动启动

4. **测试功能**
   - 点击录制按钮测试录音
   - 查看任务列表（如果没有后端，会显示空状态）

---

## 🐛 调试技巧

### 查看日志
1. 在 Xcode 底部，打开 **Console** 面板
2. 运行 APP 时，所有 `print()` 输出会显示在这里
3. 查看错误信息和调试信息

### 断点调试
1. 在代码行号左侧点击，添加断点（蓝色圆点）
2. 运行项目，程序会在断点处暂停
3. 可以查看变量值、单步执行等

### 网络请求调试
1. 在 `NetworkManager.swift` 中添加 `print` 语句：
```swift
print("请求 URL: \(baseURL)/tasks/sessions")
print("响应: \(response)")
```

---

## 📱 真机测试（可选）

如果需要在实际 iPhone 上测试：

1. **连接 iPhone 到 Mac**
2. **在 Xcode 中选择设备**
   - 顶部工具栏，选择你的 iPhone
3. **配置开发者账号**
   - 项目设置 → Signing & Capabilities
   - 选择你的 Apple ID
4. **运行项目**
   - 点击 ▶ 按钮
   - 首次运行需要在 iPhone 上信任开发者

---

## ✅ 完成检查

完成以上所有步骤后，你的项目应该：

- ✅ 所有文件都已添加到项目（蓝色图标）
- ✅ Deployment Target 设置为 iOS 16.0
- ✅ 麦克风权限已配置
- ✅ Alamofire 已安装
- ✅ API 地址已配置
- ✅ 项目可以编译通过
- ✅ APP 可以在模拟器上运行

---

**如果遇到任何问题，请查看 `iOS_PROJECT_CHECKLIST.md` 中的常见问题部分。**

