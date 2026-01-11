# 通过 Info 标签添加麦克风权限（新版 Xcode）

## 🎯 说明

在新版本的 Xcode（特别是使用 SwiftUI 的项目）中，可能没有单独的 `Info.plist` 文件。

权限配置已经集成到项目设置的 `Info` 标签中。

---

## ✅ 操作步骤

### 步骤 1: 打开项目设置

1. **在项目导航器中，点击项目名称（蓝色图标，最顶部）**

2. **点击项目名称旁边的 `>` 展开**（如果还没有展开）

3. **在 `TARGETS` 下，点击 `WorkSurvivalGuide`**
   - 确保点击的是 `WorkSurvivalGuide` target，不是项目名称

### 步骤 2: 打开 Info 标签

1. **在中间面板的顶部，查看标签栏**

2. **找到 `Info` 标签**
   - 标签栏应该显示：`General`、`Signing & Capabilities`、`Resource Tags`、**`Info`**、`Build Settings` 等
   - `Info` 标签通常在 `Resource Tags` 和 `Build Settings` 之间

3. **点击 `Info` 标签**

### 步骤 3: 添加麦克风权限

1. **在 `Info` 标签页中，找到 `Custom iOS Target Properties` 部分**
   - 这个部分通常在页面的中间或下方
   - 显示为一个表格，有 Key 和 Value 列

2. **点击左下角的 `+` 按钮**（添加新行）

3. **在 Key 列中**：
   - 点击下拉菜单或直接输入
   - 输入：`Privacy - Microphone Usage Description`
   - 或者输入：`NSMicrophoneUsageDescription`（系统会自动转换）

4. **在 Value 列（Type 列右侧）中**：
   - 输入：`需要访问麦克风以录制会议音频`

5. **按回车或点击其他地方确认**

6. **完成！** 不需要手动保存，Xcode 会自动保存

---

## 📸 操作示意图

```
Info 标签页：
┌─────────────────────────────────────────┐
│ Custom iOS Target Properties            │
├─────────────────────────────────────────┤
│ Key                          │ Value    │
├─────────────────────────────────────────┤
│ [点击 + 添加新行]                        │
│ Privacy - Microphone Usage   │ 需要访问 │
│ Description                  │ 麦克风...│
└─────────────────────────────────────────┘
```

---

## ✅ 验证添加成功

添加完成后，检查：

1. **在 `Custom iOS Target Properties` 表格中，应该能看到一行**：
   - Key: `Privacy - Microphone Usage Description`
   - Value: `需要访问麦克风以录制会议音频`

2. **如果显示正确，说明添加成功！**

---

## 🆘 如果找不到 Info 标签

### 检查：

1. **确保你点击的是 `TARGETS` 下的 `WorkSurvivalGuide`**，不是项目名称

2. **查看标签栏，`Info` 标签应该在**：
   - `Resource Tags` 和 `Build Settings` 之间
   - 或者可能在标签栏的右侧（需要向右滚动）

3. **如果确实没有 `Info` 标签**，可以尝试创建 Info.plist 文件（见下方）

---

## 🔧 方法 2: 手动创建 Info.plist（如果 Info 标签不可用）

### 步骤：

1. **在项目导航器中，右键点击 `WorkSurvivalGuide` 文件夹（蓝色图标）**

2. **选择 `New File...`**

3. **在模板选择器中**：
   - 选择 `iOS` → `Resource` → `Property List`
   - 或者直接搜索 "Property List"

4. **点击 `Next`**

5. **文件名输入**：`Info.plist`

6. **确保 `Add to targets: WorkSurvivalGuide` 被勾选**

7. **点击 `Create`**

8. **双击打开 `Info.plist` 文件**

9. **右键点击空白处** → `Add Row`

10. **添加权限**：
    - Key: `Privacy - Microphone Usage Description`
    - Value: `需要访问麦克风以录制会议音频`

11. **保存文件**（`Cmd + S`）

---

## 🎯 推荐方法

**优先使用方法 1**（通过 `Info` 标签添加），因为：
- 更简单直接
- 不需要创建新文件
- 是 Xcode 推荐的方式

---

## 📝 快速检查

请告诉我：

1. **在项目设置中，你能看到 `Info` 标签吗？**（在 `General` 标签旁边）
2. **如果能看到，点击后能看到 `Custom iOS Target Properties` 部分吗？**

告诉我你看到的情况，我会继续帮你！

