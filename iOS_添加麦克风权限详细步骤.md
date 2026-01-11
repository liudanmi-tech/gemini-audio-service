# 添加麦克风权限 - 详细步骤

## 🔍 方法 1: 在项目导航器中查找 Info.plist

### 步骤 1: 查找 Info.plist 文件

1. **在项目导航器中，查看 `WorkSurvivalGuide` 文件夹（蓝色图标）**

2. **Info.plist 文件可能在以下位置**：
   - 直接在 `WorkSurvivalGuide` 文件夹下（和 `ContentView.swift` 同级）
   - 或者在 `WorkSurvivalGuide` 文件夹内部

3. **查找文件名为 `Info.plist` 的文件**
   - 图标可能是一个列表或文档图标
   - 文件名是 `Info.plist`

4. **如果找不到，尝试以下方法**：

---

## 🔍 方法 2: 通过搜索查找

1. **在 Xcode 中，按 `Cmd + Shift + O`**（快速打开）

2. **输入**：`Info.plist`

3. **在搜索结果中，选择 `Info.plist`**

4. **文件会自动打开**

---

## 🔍 方法 3: 在 Finder 中查找

1. **在 Finder 中，导航到项目目录**：
   ```
   /Users/liudan/Desktop/AI军师/gemini-audio-service/Models.swift/WorkSurvivalGuide/WorkSurvivalGuide/
   ```

2. **查找 `Info.plist` 文件**

3. **双击打开**（会用 Xcode 打开）

---

## ✅ 找到 Info.plist 后的操作步骤

### 步骤 1: 打开 Info.plist

1. **双击 `Info.plist` 文件**

2. **文件会在 Xcode 中打开**
   - 可能显示为表格形式（Key-Value 对）
   - 或者显示为源代码形式（XML）

---

## 📝 方法 A: 通过界面添加（推荐）

### 如果 Info.plist 显示为表格形式：

1. **在表格中，右键点击空白处**（任意空白行）

2. **选择 `Add Row`**（添加行）

3. **在 Key 列中**：
   - 点击下拉菜单或直接输入
   - 输入：`Privacy - Microphone Usage Description`
   - 或者输入：`NSMicrophoneUsageDescription`（系统会自动转换为完整名称）

4. **在 Value 列（Type 列右侧）中**：
   - 输入：`需要访问麦克风以录制会议音频`

5. **保存文件**（`Cmd + S`）

---

## 📝 方法 B: 通过源代码添加

### 如果 Info.plist 显示为源代码形式（XML）：

1. **在文件内容中，找到 `<dict>` 标签**

2. **在 `<dict>` 和 `</dict>` 之间，添加以下内容**：
   ```xml
   <key>NSMicrophoneUsageDescription</key>
   <string>需要访问麦克风以录制会议音频</string>
   ```

3. **完整示例**：
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

4. **保存文件**（`Cmd + S`）

---

## 🔄 方法 C: 通过项目设置添加（如果找不到 Info.plist）

### 在新版本的 Xcode 中，可能没有单独的 Info.plist 文件：

1. **在项目导航器中，点击项目名称（蓝色图标）**

2. **在 `TARGETS` 下，点击 `WorkSurvivalGuide`**

3. **在中间面板，点击 `Info` 标签**（不是 `General`）

4. **在 `Custom iOS Target Properties` 部分**：
   - 点击左下角的 `+` 按钮
   - 在 Key 列输入：`Privacy - Microphone Usage Description`
   - 在 Value 列输入：`需要访问麦克风以录制会议音频`

5. **保存**

---

## ✅ 验证添加成功

添加完成后，检查：

1. **如果使用表格形式**：
   - 应该能看到一行：
     - Key: `Privacy - Microphone Usage Description`
     - Value: `需要访问麦克风以录制会议音频`

2. **如果使用源代码形式**：
   - 应该能看到：
     ```xml
     <key>NSMicrophoneUsageDescription</key>
     <string>需要访问麦克风以录制会议音频</string>
     ```

3. **保存文件**（`Cmd + S`）

---

## 🆘 如果找不到 Info.plist

### 在新版本的 Xcode 中，Info.plist 可能被隐藏或集成到项目设置中：

1. **尝试方法 C**：通过 `Info` 标签添加

2. **或者创建 Info.plist**：
   - 右键点击 `WorkSurvivalGuide` 文件夹
   - 选择 `New File...`
   - 选择 `Property List`
   - 文件名输入：`Info.plist`
   - 点击 `Create`
   - 然后按照方法 A 或 B 添加权限

---

## 📸 操作示意图

### 表格形式：
```
┌─────────────────────────────────────────────┐
│ Key                          │ Value        │
├─────────────────────────────────────────────┤
│ Privacy - Microphone Usage   │ 需要访问...  │
│ Description                  │              │
└─────────────────────────────────────────────┘
```

### 源代码形式：
```xml
<dict>
    <key>NSMicrophoneUsageDescription</key>
    <string>需要访问麦克风以录制会议音频</string>
</dict>
```

---

## 🎯 快速检查

请告诉我：

1. **你能在项目导航器中找到 `Info.plist` 文件吗？**
2. **如果找到了，打开后显示的是什么形式？**（表格还是源代码？）
3. **如果找不到，你能看到 `Info` 标签吗？**（在项目设置中）

告诉我你看到的情况，我会提供更准确的帮助！

