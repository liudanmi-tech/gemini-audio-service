# iOS 添加模拟器详细步骤

## 🎯 当前情况

你打开了 Devices and Simulators 窗口，但看到的是 **Devices（真实设备）** 标签。

**需要切换到 Simulators（模拟器）标签**。

---

## ✅ 操作步骤

### 步骤 1: 切换到 Simulators 标签

1. **查看窗口顶部**
   - 应该有两个标签：`Devices` 和 `Simulators`
   - 当前选中的是 `Devices`（可能高亮显示）

2. **点击 `Simulators` 标签**
   - 点击顶部的 `Simulators` 标签
   - 切换到模拟器列表

### 步骤 2: 查看现有模拟器

切换到 `Simulators` 标签后，你应该看到：
- 左侧：模拟器列表
- 右侧：模拟器详情

**查找 iOS 16 的模拟器**：
- 在左侧列表中查找
- 查看每个模拟器的 iOS 版本
- 例如：`iPhone 14 (iOS 16.0)`

### 步骤 3A: 如果有 iOS 16 模拟器

1. **选择 iOS 16 模拟器**
   - 在左侧列表中点击 iOS 16 的模拟器

2. **关闭窗口**
   - 点击窗口左上角的红色关闭按钮（或按 `Cmd + W`）

3. **在 Xcode 顶部工具栏选择**
   - 点击设备选择器（运行按钮旁边）
   - 选择刚才找到的 iOS 16 模拟器

4. **运行项目**
   - 按 `Cmd + R`

### 步骤 3B: 如果没有 iOS 16 模拟器（需要添加）

#### 3.1 点击添加按钮

1. **查看窗口左下角**
   - 应该有一个 `+` 按钮
   - 点击这个按钮

#### 3.2 配置新模拟器

会弹出一个对话框，需要填写：

1. **Device Type（设备类型）**
   - 点击下拉菜单
   - 选择：`iPhone 14` 或 `iPhone 15` 或 `iPhone SE (3rd generation)`

2. **OS Version（操作系统版本）**
   - 点击下拉菜单
   - **查找 iOS 16.0 或 iOS 16.1**
   - 如果列表中没有 iOS 16，见下方步骤 4

3. **Name（名称）**（可选）
   - 可以输入：`iPhone 14 (iOS 16)`
   - 或留空，使用默认名称

4. **点击 Create**
   - 创建模拟器

#### 3.3 关闭窗口并选择模拟器

1. **关闭 Devices and Simulators 窗口**
   - 点击窗口左上角的红色关闭按钮

2. **在 Xcode 顶部工具栏选择**
   - 点击设备选择器
   - 选择刚创建的 iOS 16 模拟器

3. **运行项目**
   - 按 `Cmd + R`

---

## ⚠️ 如果 OS Version 列表中没有 iOS 16

### 步骤 4: 下载 iOS 16 Runtime

如果在下拉菜单中找不到 iOS 16.0 或 iOS 16.1，需要下载：

#### 方法 1: 通过 Xcode Settings 下载

1. **关闭 Devices and Simulators 窗口**

2. **打开 Xcode Settings**
   - 菜单栏：`Xcode` → `Settings`
   - 或按快捷键：`Cmd + ,`

3. **切换到 Platforms 标签**
   - 点击顶部的 `Platforms` 标签
   - （有些版本可能叫 `Components`）

4. **查找 iOS 16 Runtime**
   - 在列表中查找 `iOS 16.0` 或 `iOS 16.1`
   - 应该显示为：`iOS 16.0 Simulator` 或类似

5. **下载**
   - 点击下载按钮（下载图标）
   - 等待下载完成（可能需要几分钟到几十分钟）

6. **下载完成后**
   - 回到 Devices and Simulators 窗口
   - 重新添加模拟器
   - 现在应该能看到 iOS 16 选项了

#### 方法 2: 通过命令行下载（可选）

```bash
xcodebuild -downloadPlatform iOS
```

---

## 📋 完整流程总结

1. ✅ 点击 `Simulators` 标签
2. ✅ 查看是否有 iOS 16 模拟器
3. ✅ 如果有：选择它，关闭窗口，在 Xcode 顶部选择，运行项目
4. ✅ 如果没有：点击 `+` 添加
5. ✅ 选择设备类型（iPhone 14）
6. ✅ 选择 OS Version（iOS 16.0）
7. ✅ 如果列表中没有 iOS 16：去 Xcode Settings 下载 iOS 16 Runtime
8. ✅ 创建模拟器
9. ✅ 关闭窗口，在 Xcode 顶部选择模拟器
10. ✅ 运行项目

---

## 🆘 常见问题

### 问题 1: 找不到 Simulators 标签

**原因**：窗口可能被调整了大小

**解决**：
- 尝试调整窗口大小
- 或者关闭窗口，重新打开：`Window` → `Devices and Simulators`

### 问题 2: 只有 iOS 17/18 选项

**原因**：Xcode 版本较新，默认只包含较新的 iOS 版本

**解决**：
- 下载 iOS 16 Runtime（见步骤 4）
- 或者检查 Xcode 版本，可能需要使用较旧版本的 Xcode

### 问题 3: 下载 iOS 16 Runtime 很慢

**原因**：文件较大（几 GB）

**解决**：
- 耐心等待
- 确保网络连接稳定
- 可以在后台下载，继续其他工作

---

## ✅ 检查清单

- [ ] 已切换到 `Simulators` 标签
- [ ] 查看了现有模拟器列表
- [ ] 如果没有 iOS 16 模拟器，点击 `+` 添加
- [ ] 选择了设备类型（iPhone 14）
- [ ] 选择了 OS Version（iOS 16.0）
- [ ] 如果列表中没有 iOS 16，去下载 iOS 16 Runtime
- [ ] 创建了模拟器
- [ ] 在 Xcode 顶部选择了 iOS 16 模拟器
- [ ] 运行项目成功

---

**现在先点击 `Simulators` 标签，看看有没有 iOS 16 的模拟器！**

