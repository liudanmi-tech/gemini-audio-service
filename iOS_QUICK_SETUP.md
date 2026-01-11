# iOS 项目快速设置指南（小白版）

## 🎯 5 个必须完成的设置

### ✅ 设置 1: Deployment Target 为 iOS 16.0

**步骤**：
1. 在 Xcode 左侧，点击最顶部的项目名称（蓝色图标）
2. 在中间面板，点击 `General` 标签
3. 找到 `Deployment Info` 部分
4. 点击 `iOS` 旁边的版本号下拉菜单
5. 选择 `16.0`

**详细步骤**：查看 `iOS_SET_DEPLOYMENT_TARGET.md`

---

### ✅ 设置 2: 添加麦克风权限

**方法一：通过界面添加（推荐）**

1. 在项目导航器中，找到 `Info.plist` 文件
2. 双击打开
3. 右键点击空白处 → `Add Row`
4. 在 **Key** 列输入：`Privacy - Microphone Usage Description`
5. 在 **Value** 列输入：`需要访问麦克风以录制会议音频`

**方法二：通过源代码添加**

1. 在项目导航器中，找到 `Info.plist` 文件
2. 右键点击 → `Open As` → `Source Code`
3. 在 `<dict>` 标签内（第一行 `<dict>` 和最后一行 `</dict>` 之间）添加：
```xml
<key>NSMicrophoneUsageDescription</key>
<string>需要访问麦克风以录制会议音频</string>
```

**完整示例**：
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSMicrophoneUsageDescription</key>
    <string>需要访问麦克风以录制会议音频</string>
    <!-- 其他配置... -->
</dict>
</plist>
```

---

### ✅ 设置 3: 添加 Alamofire 依赖

**步骤**：
1. 在 Xcode 中，点击项目名称（蓝色图标，最顶部）
2. 在中间面板，点击 `Package Dependencies` 标签
3. 点击左下角的 `+` 按钮
4. 在搜索框输入：`https://github.com/Alamofire/Alamofire.git`
5. 点击 `Add Package`
6. 选择版本：**Up to Next Major Version**，输入 `5.8.0`
7. 点击 `Add Package`
8. 在下一个界面，确保 **Alamofire** 被勾选
9. 点击 `Add Package`
10. 等待下载完成（可能需要几分钟）

**验证**：
- 在 `Package Dependencies` 标签中，应该能看到 Alamofire
- 在代码中输入 `import Alamofire` 不应该报错

---

### ✅ 设置 4: 配置 API 地址

**步骤**：
1. 在项目导航器中，找到 `NetworkManager.swift` 文件
2. 双击打开
3. 找到这一行（大约在第 17 行）：
```swift
private let baseURL = "http://localhost:8001/api/v1"
```

4. **根据你的情况修改**：

   **情况 A: 后端运行在本地 Mac，使用模拟器测试**
   ```swift
   private let baseURL = "http://localhost:8001/api/v1"
   ```
   保持不变即可

   **情况 B: 后端运行在服务器**
   ```swift
   private let baseURL = "http://your-server-ip:8001/api/v1"
   ```
   将 `your-server-ip` 替换为实际 IP 地址

   **情况 C: 使用真机测试，后端在 Mac 上**
   - 不能使用 `localhost`
   - 需要找到 Mac 的 IP 地址：
     1. 打开 `系统设置`（或 `系统偏好设置`）
     2. 点击 `网络`
     3. 查看当前连接的网络，找到 IP 地址（如 `192.168.1.100`）
   - 修改为：
   ```swift
   private let baseURL = "http://192.168.1.100:8001/api/v1"
   ```
   将 `192.168.1.100` 替换为你的 Mac IP 地址

5. 保存文件（`Cmd + S`）

---

### ✅ 设置 5: 确认所有文件已添加到项目

**检查方法**：
1. 在项目导航器（左侧面板）中，查看所有文件
2. **蓝色图标** ✅ = 文件已添加到项目
3. **灰色图标** ❌ = 文件未添加到项目

**如果文件是灰色的，需要添加**：

1. 右键点击灰色文件 → `Delete` → 选择 `Remove Reference`（不要选择 `Move to Trash`）

2. 重新添加文件：
   - 右键点击项目文件夹（蓝色图标）
   - 选择 `Add Files to "WorkSurvivalGuide"...`
   - 选择文件
   - **重要**：确保勾选：
     - ✅ `Copy items if needed`
     - ✅ `Add to targets: WorkSurvivalGuide`
   - 点击 `Add`

**需要检查的文件**：
- [ ] `Models.swift/File.swift`
- [ ] `NetworkManager.swift`
- [ ] `AudioRecorderService.swift`
- [ ] `TaskListViewModel.swift`
- [ ] `RecordingViewModel.swift`
- [ ] `TaskListView.swift`
- [ ] `TaskCardView.swift`
- [ ] `RecordingButtonView.swift`
- [ ] `TaskDetailView.swift`
- [ ] `ContentView.swift`

---

## 🚀 完成设置后

### 1. 清理项目
- 在 Xcode 中，选择 `Product` → `Clean Build Folder`
- 或按快捷键 `Shift + Cmd + K`

### 2. 选择模拟器
- 在顶部工具栏，点击设备选择器
- 选择 **iPhone 15 Pro** 或任意 iOS 16+ 模拟器

### 3. 运行项目
- 点击左上角的 **▶** 按钮
- 或按 `Cmd + R`
- 等待编译完成（第一次可能需要几分钟）

### 4. 测试功能
- 点击录制按钮测试录音
- 查看任务列表

---

## ❓ 遇到问题？

### 编译错误
1. 查看 Xcode 底部的错误信息
2. 点击红色错误标记，查看详细说明
3. 按照提示修复问题

### 常见错误修复

**错误: "Cannot find type 'Task'"**
- 检查 `Models.swift/File.swift` 是否已添加到项目（蓝色图标）

**错误: "No such module 'Alamofire'"**
- 重新添加 Alamofire 依赖（见设置 3）

**错误: 麦克风权限被拒绝**
- 在模拟器中：`Settings` → `Privacy` → `Microphone` → 开启权限

**错误: 网络请求失败**
- 检查 `baseURL` 是否正确
- 确认后端服务正在运行

---

## ✅ 完成检查清单

完成所有设置后，检查：

- [ ] Deployment Target 设置为 iOS 16.0
- [ ] Info.plist 中添加了麦克风权限
- [ ] Alamofire 已安装
- [ ] API 地址已配置
- [ ] 所有文件都已添加到项目（蓝色图标）
- [ ] 项目可以编译通过
- [ ] APP 可以在模拟器上运行

---

**如果所有设置都完成了，就可以开始使用 APP 了！** 🎉

