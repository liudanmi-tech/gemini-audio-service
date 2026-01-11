# iOS 修复 Scheme 问题

## 🎯 当前问题

- "Choose Scheme" 后没有出现选择器
- "Product → Run" 是灰色的（不可点击）

**这说明项目可能没有正确配置 Scheme。**

---

## ✅ 解决方案

### 方法 1: 创建新 Scheme

1. **菜单栏**：`Product` → `Scheme` → `New Scheme...`

2. **会弹出创建 Scheme 对话框**：
   - **Target**: 选择 `WorkSurvivalGuide`
   - **Name**: 输入 `WorkSurvivalGuide`（或使用默认名称）
   - 点击 "OK"

3. **创建完成后**：
   - Scheme 应该会出现在列表中
   - "Run" 应该可以点击了

---

### 方法 2: 管理 Schemes

1. **菜单栏**：`Product` → `Scheme` → `Manage Schemes...`

2. **会打开 Scheme 管理窗口**：
   - 查看是否有 "WorkSurvivalGuide" Scheme
   - 如果没有，点击左下角的 `+` 按钮
   - 创建新 Scheme

3. **如果有但未勾选**：
   - 确保 "WorkSurvivalGuide" 前面的复选框被勾选
   - 点击 "Close"

---

### 方法 3: 检查项目配置

1. **在项目导航器中，点击最顶部的蓝色项目图标**
   - 应该显示项目设置

2. **查看 Targets**：
   - 在中间面板，应该能看到 "WorkSurvivalGuide" target
   - 如果没有，说明项目配置有问题

3. **选择 Target**：
   - 点击 "WorkSurvivalGuide" target
   - 查看 General 标签

---

### 方法 4: 尝试先编译项目

1. **菜单栏**：`Product` → `Build`
   - 或按 `Cmd + B`

2. **查看结果**：
   - 如果编译成功，Scheme 可能会自动创建
   - 如果有错误，告诉我具体的错误信息

---

## 🔍 详细操作步骤

### 步骤 1: 尝试创建新 Scheme

1. **菜单栏**：`Product` → `Scheme` → `New Scheme...`

2. **在对话框中**：
   - **Target**: 下拉菜单，选择 `WorkSurvivalGuide`
   - **Name**: 使用默认名称或输入 `WorkSurvivalGuide`
   - 点击 "OK"

3. **检查结果**：
   - Scheme 是否创建成功？
   - "Run" 是否可以点击了？

---

### 步骤 2: 如果创建 Scheme 时没有 Target 选项

这说明项目配置可能有问题：

1. **检查项目导航器**：
   - 最顶部应该有蓝色的项目图标
   - 点击它

2. **查看中间面板**：
   - 应该显示项目设置
   - 查看 "TARGETS" 部分
   - 应该能看到 "WorkSurvivalGuide"

3. **如果没有 Target**：
   - 可能需要重新创建项目
   - 或者项目文件损坏

---

### 步骤 3: 尝试编译项目

1. **菜单栏**：`Product` → `Build`
   - 或按 `Cmd + B`

2. **查看 Xcode 底部**：
   - 是否有编译错误？
   - 是否有警告？

3. **告诉我结果**：
   - 编译成功？
   - 还是有错误？

---

## 🆘 如果所有方法都不行

### 可能的原因：

1. **项目文件损坏**
   - 需要重新创建项目

2. **Xcode 版本问题**
   - 可能需要更新 Xcode

3. **项目没有正确打开**
   - 需要重新打开项目文件

---

## 📋 现在操作

### 第一步：尝试创建新 Scheme

1. **菜单栏**：`Product` → `Scheme` → `New Scheme...`

2. **告诉我结果**：
   - 弹出对话框了吗？
   - 对话框中有什么选项？
   - 有 "WorkSurvivalGuide" Target 吗？

### 第二步：如果创建失败，检查项目

1. **在项目导航器中，点击最顶部的蓝色项目图标**

2. **查看中间面板**：
   - 有 "TARGETS" 部分吗？
   - 能看到 "WorkSurvivalGuide" target 吗？

3. **告诉我你看到了什么**

### 第三步：尝试编译

1. **菜单栏**：`Product` → `Build`
   - 或按 `Cmd + B`

2. **告诉我结果**：
   - 编译成功？
   - 还是有错误？

---

**现在先尝试 `Product` → `Scheme` → `New Scheme...`，告诉我你看到了什么！**

