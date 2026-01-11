# iOS 选择模拟器指南

## 🎯 问题：Xcode 提示需要下载 iOS 18.5

**原因**：Xcode 自动选择了 iOS 18.5 的模拟器，但你的项目是 iOS 16。

**解决**：不需要下载，只需要选择正确的模拟器。

---

## ✅ 解决步骤

### 步骤 1: 取消下载

1. **点击 "Cancel" 按钮**
   - 不需要下载 iOS 18.5
   - 关闭弹窗

### 步骤 2: 选择 iOS 16 模拟器

1. **查看 Xcode 顶部工具栏**
   - 找到设备选择器（在运行按钮旁边）
   - 显示类似：`iPhone 15 Pro (iOS 18.5)` 或 `Any iOS Device`

2. **点击设备选择器**
   - 会弹出模拟器列表

3. **选择 iOS 16 的模拟器**
   - 查找包含 "iOS 16" 的模拟器
   - 例如：
     - `iPhone 14 (iOS 16.0)`
     - `iPhone 15 (iOS 16.0)`
     - `iPhone SE (3rd generation) (iOS 16.0)`

4. **如果没有 iOS 16 模拟器**：
   - 需要添加 iOS 16 模拟器（见下方步骤）

---

## 📱 添加 iOS 16 模拟器（如果没有）

### 方法 1: 通过 Xcode 添加

1. **打开设备管理器**
   - 菜单栏：`Window` → `Devices and Simulators`
   - 或按快捷键：`Shift + Cmd + 2`

2. **切换到 Simulators 标签**
   - 点击顶部的 `Simulators` 标签

3. **添加新模拟器**
   - 点击左下角的 `+` 按钮

4. **配置模拟器**
   - **Device Type**: 选择 `iPhone 14` 或 `iPhone 15`
   - **OS Version**: 选择 `iOS 16.0` 或 `iOS 16.1`
   - **Name**: 输入名称，如 `iPhone 14 (iOS 16)`

5. **点击 Create**

### 方法 2: 检查是否有 iOS 16 Runtime

如果没有 iOS 16 选项，需要下载 iOS 16 Runtime：

1. **打开 Xcode 设置**
   - 菜单栏：`Xcode` → `Settings`（或 `Preferences`）
   - 或按快捷键：`Cmd + ,`

2. **切换到 Platforms 标签**
   - 点击 `Platforms`（或 `Components`）

3. **下载 iOS 16 Runtime**
   - 查找 `iOS 16.0` 或 `iOS 16.1`
   - 点击下载按钮（下载图标）

4. **等待下载完成**
   - 可能需要几分钟到几十分钟，取决于网络速度

---

## 🔍 检查 Deployment Target

确保项目的 Deployment Target 是 iOS 16.0：

1. **选择项目**
   - 在项目导航器中，点击最顶部的蓝色项目图标

2. **选择 Target**
   - 在中间面板，选择 `WorkSurvivalGuide` target

3. **查看 General 标签**
   - 找到 `Deployment Info` 部分
   - 确认 `iOS Deployment Target` 是 `16.0`

4. **如果不是 16.0**：
   - 点击下拉菜单
   - 选择 `iOS 16.0`

---

## 📋 快速检查清单

- [ ] 点击 Cancel，关闭 iOS 18.5 下载弹窗
- [ ] 在顶部工具栏选择 iOS 16 模拟器
- [ ] 确认 Deployment Target 是 iOS 16.0
- [ ] 如果没有 iOS 16 模拟器，添加一个
- [ ] 重新运行项目（`Cmd + R`）

---

## 🆘 常见问题

### 问题 1: 没有 iOS 16 模拟器选项

**原因**：Xcode 没有安装 iOS 16 Runtime

**解决**：
1. 打开 `Xcode` → `Settings` → `Platforms`
2. 下载 iOS 16.0 或 iOS 16.1 Runtime
3. 等待下载完成
4. 重新添加模拟器

### 问题 2: 只有 iOS 17/18 模拟器

**原因**：新版本的 Xcode 可能默认只包含较新的 iOS 版本

**解决**：
1. 下载 iOS 16 Runtime（见上方步骤）
2. 或者临时使用 iOS 17 模拟器（如果 Deployment Target 允许）

### 问题 3: 模拟器列表为空

**原因**：Xcode 没有安装任何模拟器

**解决**：
1. 打开 `Window` → `Devices and Simulators`
2. 点击 `+` 添加模拟器
3. 选择设备和 iOS 版本

---

## ✅ 推荐配置

**推荐的模拟器**：
- `iPhone 14 (iOS 16.0)` - 标准尺寸
- `iPhone SE (3rd generation) (iOS 16.0)` - 小屏幕测试
- `iPhone 15 Pro (iOS 16.0)` - 最新设备

**Deployment Target**：
- `iOS 16.0`（你已设置）

---

**现在点击 Cancel，然后选择 iOS 16 模拟器，重新运行项目即可！**


