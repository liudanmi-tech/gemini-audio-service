# iOS 从零添加模拟器步骤

## 🎯 当前情况

模拟器列表为空，需要添加一个 iOS 16 的模拟器。

---

## ✅ 操作步骤

### 步骤 1: 点击添加按钮

1. **查看窗口左下角**
   - 应该有一个 `+` 按钮
   - 点击这个按钮

### 步骤 2: 配置新模拟器

点击 `+` 后，会弹出一个对话框，需要填写：

#### 2.1 选择 Device Type（设备类型）

1. **点击 "Device Type" 下拉菜单**
   - 选择：`iPhone 14` 或 `iPhone 15` 或 `iPhone SE (3rd generation)`
   - **推荐**：`iPhone 14`（标准尺寸，适合测试）

#### 2.2 选择 OS Version（操作系统版本）

1. **点击 "OS Version" 下拉菜单**
   - **查找 `iOS 16.0` 或 `iOS 16.1`**
   - 如果列表中有，选择它
   - **如果列表中没有 iOS 16**，见下方步骤 3

#### 2.3 输入 Name（名称，可选）

1. **在 "Name" 输入框**
   - 可以输入：`iPhone 14 (iOS 16)`
   - 或留空，使用默认名称

#### 2.4 创建模拟器

1. **点击 "Create" 按钮**
   - 创建模拟器

---

## ⚠️ 如果 OS Version 列表中没有 iOS 16

### 步骤 3: 下载 iOS 16 Runtime

如果在下拉菜单中找不到 iOS 16.0 或 iOS 16.1，需要先下载：

#### 3.1 取消添加对话框

1. **点击 "Cancel" 按钮**
   - 关闭添加模拟器的对话框

#### 3.2 打开 Xcode Settings

1. **关闭 Devices and Simulators 窗口**
   - 点击窗口左上角的红色关闭按钮
   - 或按 `Cmd + W`

2. **打开 Xcode Settings**
   - 菜单栏：`Xcode` → `Settings`
   - 或按快捷键：`Cmd + ,`

#### 3.3 切换到 Platforms 标签

1. **点击顶部的 `Platforms` 标签**
   - （有些版本可能叫 `Components` 或 `Locations`）

#### 3.4 查找并下载 iOS 16 Runtime

1. **在列表中查找**
   - 查找 `iOS 16.0 Simulator` 或 `iOS 16.1 Simulator`
   - 应该显示为：`iOS 16.0` 或类似

2. **查看状态**
   - 如果显示下载图标（向下箭头），说明需要下载
   - 如果显示已安装，说明已经下载了

3. **点击下载**
   - 点击下载按钮（下载图标）
   - 会显示下载进度

4. **等待下载完成**
   - 文件较大（几 GB），可能需要几分钟到几十分钟
   - 可以在后台下载，继续其他工作

#### 3.5 下载完成后重新添加模拟器

1. **关闭 Xcode Settings**
   - 点击窗口左上角的红色关闭按钮

2. **重新打开 Devices and Simulators**
   - 菜单栏：`Window` → `Devices and Simulators`
   - 或按 `Shift + Cmd + 2`

3. **切换到 Simulators 标签**
   - 点击顶部的 `Simulators` 标签

4. **点击 `+` 按钮**
   - 重新添加模拟器

5. **现在应该能看到 iOS 16 选项了**
   - 选择 `iOS 16.0` 或 `iOS 16.1`

6. **完成创建**
   - 选择设备类型（iPhone 14）
   - 选择 OS Version（iOS 16.0）
   - 点击 Create

---

## 📋 完整流程（如果列表为空）

### 情况 A: OS Version 列表中有 iOS 16

1. ✅ 点击 `+` 按钮
2. ✅ 选择 Device Type（iPhone 14）
3. ✅ 选择 OS Version（iOS 16.0）
4. ✅ 输入 Name（可选）
5. ✅ 点击 Create
6. ✅ 关闭窗口
7. ✅ 在 Xcode 顶部选择模拟器
8. ✅ 运行项目

### 情况 B: OS Version 列表中没有 iOS 16

1. ✅ 点击 `+` 按钮
2. ✅ 发现没有 iOS 16 选项
3. ✅ 点击 Cancel
4. ✅ 关闭 Devices and Simulators 窗口
5. ✅ 打开 Xcode Settings（`Cmd + ,`）
6. ✅ 切换到 Platforms 标签
7. ✅ 下载 iOS 16 Runtime
8. ✅ 等待下载完成
9. ✅ 重新打开 Devices and Simulators
10. ✅ 切换到 Simulators 标签
11. ✅ 点击 `+` 按钮
12. ✅ 选择 Device Type（iPhone 14）
13. ✅ 选择 OS Version（iOS 16.0）
14. ✅ 点击 Create
15. ✅ 关闭窗口
16. ✅ 在 Xcode 顶部选择模拟器
17. ✅ 运行项目

---

## 🎯 现在操作

### 第一步：点击 `+` 按钮

1. **在 Devices and Simulators 窗口左下角**
   - 找到 `+` 按钮
   - 点击它

### 第二步：查看 OS Version 列表

1. **点击 "OS Version" 下拉菜单**
   - 查看列表中有什么版本
   - **告诉我你看到了什么**：
     - 有 iOS 16.0 或 iOS 16.1？
     - 只有 iOS 17/18？
     - 列表是空的？

---

## 🆘 如果遇到问题

### 问题 1: 点击 `+` 没有反应

**解决**：
- 确保在 `Simulators` 标签（不是 `Devices` 标签）
- 尝试重新打开窗口

### 问题 2: 下载 iOS 16 Runtime 很慢

**解决**：
- 这是正常的，文件很大（几 GB）
- 耐心等待
- 可以在后台下载，继续其他工作

### 问题 3: 找不到 Platforms 标签

**解决**：
- 不同版本的 Xcode 可能名称不同
- 查找：`Components`、`Locations`、`Platforms`
- 或者查看所有标签

---

**现在先点击 `+` 按钮，然后告诉我 OS Version 列表里有什么选项！**

