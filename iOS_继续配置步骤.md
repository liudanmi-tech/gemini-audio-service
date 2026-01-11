# iOS 项目继续配置步骤

## ✅ 已完成
- [x] 文件夹结构已创建
- [x] 所有代码文件已创建
- [x] 重复文件夹已清理

## 📋 接下来要完成的配置

### 步骤 1: 添加 Alamofire 依赖

1. **在项目导航器中，点击项目名称（蓝色图标，最顶部）**
   - 项目名称应该是 `WorkSurvivalGuide`（带蓝色图标）

2. **在中间面板，点击 `Package Dependencies` 标签**
   - 如果看不到这个标签，可能需要先点击项目名称旁边的 `>` 展开

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

**验证**：在 `Package Dependencies` 标签中，应该能看到 Alamofire

---

### 步骤 2: 设置 Deployment Target 为 iOS 16.0

1. **在项目导航器中，点击项目名称（蓝色图标）**

2. **点击项目名称旁边的 `>` 展开**

3. **在 `TARGETS` 下，点击 `WorkSurvivalGuide`**

4. **在中间面板，点击 `General` 标签**

5. **向下滚动，找到 `Deployment Info` 部分**

6. **点击 `iOS` 右侧的版本号下拉菜单**

7. **选择 `16.0`**

8. **完成！** 版本会自动更新

---

### 步骤 3: 添加麦克风权限

1. **在项目导航器中，找到 `Info.plist` 文件**
   - 通常在项目根目录下
   - 如果找不到，可能在 `WorkSurvivalGuide` 文件夹下

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

---

### 步骤 4: 配置 API 地址

1. **在项目导航器中，打开 `Services/NetworkManager.swift`**

2. **找到这一行**（大约第 17 行）：
   ```swift
   private let baseURL = "http://localhost:8001/api/v1"
   ```

3. **根据你的情况修改**：
   - **本地测试（模拟器）**：保持不变 `http://localhost:8001/api/v1`
   - **服务器**：修改为 `http://your-server-ip:8001/api/v1`
   - **真机测试（后端在 Mac）**：使用 Mac 的 IP 地址，如 `http://192.168.1.100:8001/api/v1`

4. **保存文件**（`Cmd + S`）

---

### 步骤 5: 测试编译

1. **清理项目**（可选，但推荐）：
   - 在 Xcode 中，选择 `Product` → `Clean Build Folder`
   - 或按快捷键：`Shift + Cmd + K`

2. **编译项目**：
   - 按 `Cmd + B` 编译项目
   - 查看是否有错误

3. **如果有编译错误**：
   - 查看 Xcode 底部的错误信息
   - 告诉我具体的错误信息，我会帮你解决

---

## ✅ 完成检查清单

完成所有配置后，检查：

- [ ] Alamofire 已安装（在 Package Dependencies 中可见）
- [ ] Deployment Target 设置为 iOS 16.0
- [ ] Info.plist 中添加了麦克风权限
- [ ] NetworkManager.swift 中的 baseURL 已配置
- [ ] 项目可以编译通过（`Cmd + B` 无错误）

---

## 🚀 如果编译成功

1. **选择模拟器**（顶部工具栏，选择 iPhone 15 Pro 或任意 iOS 16+ 模拟器）

2. **运行项目**：
   - 点击左上角的 **▶** 按钮
   - 或按 `Cmd + R`

3. **测试功能**：
   - 点击录制按钮测试录音
   - 查看任务列表

---

## 🆘 如果编译报错

### 常见错误 1: "No such module 'Alamofire'"

**解决方法**：
- 重新添加 Alamofire 依赖（见步骤 1）
- 等待下载完成
- 清理项目后重新编译

### 常见错误 2: "Cannot find type 'Task'"

**解决方法**：
- 检查 `Models/Task.swift` 是否已添加到项目（蓝色图标）
- 如果没有，右键点击 `Models` 文件夹 → `Add Files...` → 选择 `Task.swift`

### 常见错误 3: 其他编译错误

**解决方法**：
- 查看 Xcode 底部的错误信息
- 点击红色错误标记，查看详细说明
- 告诉我具体的错误信息

---

## 📝 下一步

完成所有配置后，就可以运行项目了！

如果遇到任何问题，告诉我具体的错误信息或在哪一步遇到了困难。

