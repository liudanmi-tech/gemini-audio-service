# 如何添加 Alamofire 依赖 - 超详细步骤

## 🎯 找到 Package Dependencies 的方法

### 方法 1: 通过项目设置（最常用）

#### 步骤：

1. **在项目导航器中，点击项目名称（蓝色图标，最顶部）**
   - 项目名称是 `WorkSurvivalGuide`（带蓝色图标）
   - 不是下面的文件夹，是最顶部的那个

2. **点击后，中间面板应该显示项目设置**
   - 你应该能看到多个标签：`General`、`Signing & Capabilities`、`Resource Tags`、`Info`、`Build Settings`、`Build Phases`、`Build Rules` 等

3. **查找 `Package Dependencies` 标签**
   - 这个标签通常在标签栏的**中间或偏右位置**
   - 可能显示为 `Package Dependencies` 或 `Swift Packages`
   - 如果标签栏很长，可能需要**向右滚动**查看

4. **如果还是找不到，尝试以下方法**：

---

### 方法 2: 通过菜单栏

1. **点击顶部菜单栏的 `File`（文件）**

2. **在下拉菜单中查找**：
   - `Add Package Dependencies...`（添加包依赖...）
   - 或者 `Swift Packages` → `Add Package Dependency...`

3. **点击它**

4. **会弹出添加包的对话框**

---

### 方法 3: 通过项目导航器

1. **在项目导航器中，右键点击项目名称（蓝色图标）**

2. **在右键菜单中查找**：
   - `Add Package Dependencies...`
   - 或者 `Swift Packages` → `Add Package Dependency...`

3. **点击它**

---

## 📝 详细操作步骤（如果找到了 Package Dependencies）

### 步骤 1: 打开 Package Dependencies

1. **点击 `Package Dependencies` 标签**

2. **你应该能看到一个列表**（可能是空的，如果还没有添加任何包）

3. **左下角应该有一个 `+` 按钮**

### 步骤 2: 添加 Alamofire

1. **点击左下角的 `+` 按钮**

2. **会弹出一个对话框，顶部有一个搜索框**

3. **在搜索框中输入**：
   ```
   https://github.com/Alamofire/Alamofire.git
   ```

4. **按回车或等待自动搜索**

5. **在搜索结果中，应该能看到 `Alamofire`**

6. **点击 `Alamofire`，然后点击右下角的 `Add Package` 按钮**

7. **在下一个界面**：
   - 选择版本规则：**Up to Next Major Version**
   - 输入版本：`5.8.0`
   - 点击 `Add Package`

8. **在最后一个界面**：
   - 确保 `Alamofire` 被勾选
   - 确保 `WorkSurvivalGuide` target 被勾选
   - 点击 `Add Package`

9. **等待下载完成**（可能需要几分钟）

---

## 🔍 如果还是找不到 Package Dependencies

### 检查 Xcode 版本

1. **点击顶部菜单栏的 `Xcode` → `About Xcode`**
2. **查看版本号**
3. **如果版本太旧（低于 11.0），可能不支持 Package Dependencies**

### 替代方法：使用 CocoaPods（如果 Package Dependencies 不可用）

如果确实找不到 Package Dependencies，可以使用 CocoaPods：

1. **安装 CocoaPods**（如果还没有）：
   ```bash
   sudo gem install cocoapods
   ```

2. **在项目根目录创建 `Podfile`**：
   ```ruby
   platform :ios, '16.0'
   use_frameworks!

   target 'WorkSurvivalGuide' do
     pod 'Alamofire', '~> 5.8'
   end
   ```

3. **安装依赖**：
   ```bash
   pod install
   ```

4. **以后使用 `.xcworkspace` 文件打开项目**（不是 `.xcodeproj`）

---

## 🆘 我可以帮你做什么？

### 我可以：
1. ✅ **创建详细的步骤指南**（已完成）
2. ✅ **提供替代方法**（CocoaPods）
3. ✅ **帮你检查 Xcode 版本**
4. ✅ **提供其他解决方案**

### 我不能：
1. ❌ **直接在 Xcode 中操作**（我无法控制你的 Xcode）
2. ❌ **自动添加依赖**（需要你在 Xcode 中操作）

---

## 📸 你现在看到的界面

从你的截图看，你当前在 `General` 标签页。

**要找到 Package Dependencies**：
1. **查看标签栏**（在 `General`、`Signing & Capabilities` 等标签的位置）
2. **向右滚动标签栏**，查找 `Package Dependencies` 或 `Swift Packages`
3. **或者尝试方法 2**：通过菜单栏 `File` → `Add Package Dependencies...`

---

## 🎯 快速检查

请告诉我：

1. **你能看到标签栏吗？**（有 `General`、`Signing & Capabilities` 等标签）
2. **标签栏可以向右滚动吗？**（可能 Package Dependencies 在右侧）
3. **你的 Xcode 版本是什么？**（`Xcode` → `About Xcode` 查看）
4. **菜单栏中有 `File` → `Add Package Dependencies...` 吗？**

告诉我你看到的情况，我会提供更准确的帮助！

