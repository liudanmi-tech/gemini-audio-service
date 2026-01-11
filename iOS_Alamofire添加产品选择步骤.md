# Alamofire 添加产品选择步骤

## 📋 当前对话框说明

你看到的是 **"Choose Package Products for Alamofire.git"** 对话框。

这个对话框让你选择：
1. 要添加哪个产品（Alamofire 或 AlamofireDynamic）
2. 添加到哪个 Target（WorkSurvivalGuide）

---

## ✅ 正确的操作步骤

### 步骤 1: 选择 Alamofire 产品

在表格的第一行，找到 **"Alamofire"**（不是 AlamofireDynamic）

### 步骤 2: 选择 Target

1. **在第一行 "Alamofire" 的右侧，找到 "Add to Target" 列**
2. **点击 "None" 旁边的下拉箭头**（上下箭头图标）
3. **在下拉菜单中选择 `WorkSurvivalGuide`**
   - 这是你的主应用 Target
   - 不要选择 `WorkSurvivalGuideTests` 或 `WorkSurvivalGuideUITests`

### 步骤 3: 忽略 AlamofireDynamic（可选）

- **第二行 "AlamofireDynamic"** 可以保持为 "None"
- 我们只需要 `Alamofire`，不需要 `AlamofireDynamic`

### 步骤 4: 点击 Add Package

1. **确认第一行显示**：
   - Package Product: `Alamofire`
   - Kind: `Library`
   - Add to Target: `WorkSurvivalGuide` ✅

2. **点击右下角的 `Add Package` 按钮**（蓝色高亮按钮）

3. **等待下载和集成完成**（可能需要几分钟）

---

## 📸 操作示意图

```
┌─────────────────────────────────────────┐
│ Choose Package Products for Alamofire.git│
├─────────────────────────────────────────┤
│ Package Product │ Kind    │ Add to Target│
├─────────────────────────────────────────┤
│ Alamofire       │ Library │ WorkSurvival │ ← 选择这个！
│                 │         │ Guide ▼      │
├─────────────────────────────────────────┤
│ AlamofireDynamic│ Library │ None         │ ← 保持 None
└─────────────────────────────────────────┘
         [Cancel]              [Add Package] ← 点击这个！
```

---

## ✅ 完成后的验证

添加完成后，你应该看到：

1. **在项目导航器中**：
   - 在 `Package Dependencies` 标签中，应该能看到 `Alamofire`
   - 或者项目导航器中会出现 `Package Dependencies` 文件夹，里面有 `Alamofire`

2. **在代码中**：
   - 在 `NetworkManager.swift` 中，`import Alamofire` 不应该报错

---

## 🆘 如果遇到问题

### 问题 1: 下拉菜单中没有 WorkSurvivalGuide

**解决方法**：
- 确保项目已正确打开
- 尝试关闭对话框，重新添加包

### 问题 2: 添加后编译报错 "No such module 'Alamofire'"

**解决方法**：
1. 清理项目：`Product` → `Clean Build Folder`（或 `Shift + Cmd + K`）
2. 重新编译：`Cmd + B`
3. 如果还不行，检查 `Package Dependencies` 标签中是否能看到 Alamofire

---

## 🎯 快速操作总结

1. ✅ 第一行 "Alamofire" → "Add to Target" → 选择 `WorkSurvivalGuide`
2. ✅ 第二行 "AlamofireDynamic" → 保持 "None"（不需要）
3. ✅ 点击 `Add Package` 按钮
4. ✅ 等待完成

完成这些步骤后，Alamofire 就添加成功了！


