# iOS 项目逐步设置指南

## 📋 设置步骤总览

1. ✅ 确认文件已添加到项目
2. ✅ 设置 Deployment Target 为 iOS 16.0
3. ✅ 在 Info.plist 中添加麦克风权限
4. ✅ 添加 Alamofire 依赖
5. ✅ 配置 API 地址
6. ✅ 运行项目

---

## 步骤 1: 确认文件已添加到项目

### 检查方法：

1. **在项目导航器（左侧面板）中，查看所有文件**
   - 如果文件显示为**蓝色图标** ✅ = 已添加到项目
   - 如果文件显示为**灰色图标** ❌ = 未添加到项目

### 需要检查的文件：

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

### 如果文件是灰色的，需要添加：

1. **右键点击灰色文件** → `Delete` → 选择 `Remove Reference`（不要选择 `Move to Trash`）

2. **重新添加文件**：
   - 右键点击项目文件夹（蓝色图标）
   - 选择 `Add Files to "WorkSurvivalGuide"...`
   - 选择文件
   - **重要**：确保勾选：
     - ✅ `Copy items if needed`
     - ✅ `Add to targets: WorkSurvivalGuide`
   - 点击 `Add`

---

## 步骤 2: 设置 Deployment Target 为 iOS 16.0

### 详细步骤：

1. **在项目导航器中，找到项目名称（蓝色图标，最顶部）**

2. **点击项目名称旁边的** `>` **（小箭头）展开**
   - 展开后，你应该能看到 `TARGETS` 部分

3. **在 `TARGETS` 下，点击 `WorkSurvivalGuide`**
   - 点击后，中间面板应该显示项目设置

4. **在中间面板顶部，点击 `General` 标签**

5. **向下滚动，找到 `Deployment Info` 部分**

6. **点击 `iOS` 右侧的版本号下拉菜单**

7. **选择 `16.0`**

8. **完成！** 版本会自动更新为 `16.0`

**如果找不到，查看**：`iOS_SET_DEPLOYMENT_TARGET_最终方法.md`

---

## 步骤 3: 在 Info.plist 中添加麦克风权限

### 方法一：通过界面添加（推荐）

1. **在项目导航器中，找到 `Info.plist` 文件**
   - 通常在项目根目录下

2. **双击打开 `Info.plist`**

3. **右键点击空白处** → `Add Row`

4. **在 Key 列输入**：
   ```
   Privacy - Microphone Usage Description
   ```

5. **在 Value 列输入**：
   ```
   需要访问麦克风以录制会议音频
   ```

6. **保存文件**（`Cmd + S`）

### 方法二：通过源代码添加

1. **在项目导航器中，找到 `Info.plist` 文件**

2. **右键点击** → `Open As` → `Source Code`

3. **在 `<dict>` 标签内添加**（在第一行 `<dict>` 和最后一行 `</dict>` 之间）：
   ```xml
   <key>NSMicrophoneUsageDescription</key>
   <string>需要访问麦克风以录制会议音频</string>
   ```

4. **保存文件**（`Cmd + S`）

---

## 步骤 4: 添加 Alamofire 依赖

### 详细步骤：

1. **在项目导航器中，点击项目名称（蓝色图标，最顶部）**

2. **在中间面板，点击 `Package Dependencies` 标签**
   - 如果看不到这个标签，可能需要先点击项目名称

3. **点击左下角的 `+` 按钮**

4. **在搜索框中输入**：
   ```
   https://github.com/Alamofire/Alamofire.git
   ```

5. **点击 `Add Package`**

6. **选择版本**：
   - 选择 **Up to Next Major Version**
   - 输入：`5.8.0`
   - 点击 `Add Package`

7. **在下一个界面，确保 `Alamofire` 被勾选**

8. **点击 `Add Package`**

9. **等待下载完成**（可能需要几分钟）

### 验证安装：

- 在 `Package Dependencies` 标签中，应该能看到 Alamofire
- 在代码中输入 `import Alamofire` 不应该报错

---

## 步骤 5: 配置 API 地址

### 详细步骤：

1. **在项目导航器中，找到 `NetworkManager.swift` 文件**

2. **双击打开**

3. **找到这一行**（大约在第 17 行）：
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

5. **保存文件**（`Cmd + S`）

---

## 步骤 6: 运行项目

### 详细步骤：

1. **清理项目**（可选，但推荐）：
   - 在 Xcode 中，选择 `Product` → `Clean Build Folder`
   - 或按快捷键：`Shift + Cmd + K`

2. **选择模拟器**：
   - 在顶部工具栏，点击设备选择器（显示当前设备的地方）
   - 选择 **iPhone 15 Pro** 或任意 iOS 16+ 模拟器

3. **运行项目**：
   - 点击左上角的 **▶** 按钮
   - 或按快捷键：`Cmd + R`

4. **等待编译完成**：
   - 第一次编译可能需要几分钟
   - 编译完成后，模拟器会自动启动并运行 APP

5. **测试功能**：
   - 点击录制按钮测试录音
   - 查看任务列表（如果没有后端，会显示空状态）

---

## ✅ 完成检查清单

完成所有设置后，检查：

- [ ] 所有文件都已添加到项目（蓝色图标）
- [ ] Deployment Target 设置为 iOS 16.0
- [ ] Info.plist 中添加了麦克风权限
- [ ] Alamofire 已安装
- [ ] API 地址已配置
- [ ] 项目可以编译通过
- [ ] APP 可以在模拟器上运行

---

## 🐛 常见问题解决

### 问题 1: 编译错误 - "Cannot find type 'Task'"

**原因**: 文件没有正确添加到项目中

**解决方法**:
1. 检查 `Models.swift/File.swift` 是否已添加到项目（蓝色图标）
2. 如果没有，按照步骤 1 重新添加

### 问题 2: 编译错误 - "No such module 'Alamofire'"

**原因**: Alamofire 没有正确安装

**解决方法**:
1. 重新添加 Alamofire 依赖（见步骤 4）
2. 等待下载完成
3. 清理项目后重新编译

### 问题 3: 运行时错误 - 麦克风权限被拒绝

**解决方法**:
- **模拟器**: `Settings` → `Privacy` → `Microphone` → 开启权限
- **真机**: `Settings` → `WorkSurvivalGuide` → `Microphone` → 开启权限

### 问题 4: 网络请求失败

**检查项**:
1. 确认后端服务正在运行
2. 确认 `baseURL` 地址正确
3. 如果使用模拟器访问本地服务器，使用 `http://localhost:8001`
4. 如果使用真机访问本地服务器，使用 Mac 的 IP 地址

---

## 🎉 完成！

如果所有步骤都完成了，你的 iOS 项目应该可以正常运行了！

如果遇到任何问题，请告诉我具体在哪一步遇到了困难，我会帮你解决。

