# iOS Mock 数据使用指南

## 🎯 快速开始

### 当前状态

✅ **已创建的文件**：
- `Shared/AppConfig.swift` - 环境配置（Mock/真实 API 切换）
- `Services/MockNetworkService.swift` - Mock 数据服务
- `Services/NetworkManager.swift` - 已修改，支持 Mock 切换

---

## 📋 使用步骤

### 步骤 1: 在 Xcode 中添加新文件

#### 1.1 添加 AppConfig.swift

1. 在项目导航器中，右键点击 `WorkSurvivalGuide` 文件夹
2. 选择 `New Group`，命名为 `Shared`
3. 右键点击 `Shared` 文件夹
4. 选择 `Add Files to "WorkSurvivalGuide"...`
5. 找到并选择 `Shared/AppConfig.swift`
6. 确保勾选 `Copy items if needed` 和 `Add to targets: WorkSurvivalGuide`
7. 点击 `Add`

#### 1.2 添加 MockNetworkService.swift

1. 在项目导航器中，找到 `Services` 文件夹
2. 右键点击 `Services` 文件夹
3. 选择 `Add Files to "WorkSurvivalGuide"...`
4. 找到并选择 `Services/MockNetworkService.swift`
5. 确保勾选 `Copy items if needed` 和 `Add to targets: WorkSurvivalGuide`
6. 点击 `Add`

#### 1.3 更新 NetworkManager.swift

`NetworkManager.swift` 已经修改完成，支持 Mock 数据切换。

---

## 🔧 配置说明

### 默认行为

**在 DEBUG 模式下**（开发时）：
- ✅ **默认使用 Mock 数据**
- 无需任何配置，直接运行即可看到 Mock 数据

**在 RELEASE 模式下**（发布时）：
- ✅ **默认使用真实 API**
- 自动切换到生产环境

### 手动切换（可选）

如果你想在运行时切换，可以添加一个设置页面：

```swift
// 在任何地方调用
AppConfig.shared.setUseMockData(true)  // 使用 Mock
AppConfig.shared.setUseMockData(false) // 使用真实 API
```

---

## 🧪 测试流程

### 阶段 1: Mock 数据测试（当前阶段）

1. **直接运行项目**
   - 按 `Cmd + R` 运行
   - 应该能看到 Mock 任务列表

2. **测试功能**：
   - ✅ 任务列表显示（应该看到 5 个 Mock 任务）
   - ✅ 任务卡片样式
   - ✅ 下拉刷新
   - ✅ 录制按钮
   - ✅ 任务详情页

3. **验证交互**：
   - 点击任务卡片
   - 测试录制功能（会返回 Mock 响应）

### 阶段 2: 切换到真实 API

1. **修改配置**：
   ```swift
   // 在 AppConfig.swift 中，或者运行时调用
   AppConfig.shared.setUseMockData(false)
   ```

2. **修改 API 地址**：
   ```swift
   // 在 NetworkManager.swift 中
   private let baseURL = "http://47.79.254.213/api/v1"
   ```

3. **测试连接**：
   - 先测试健康检查接口
   - 再测试获取任务列表
   - 最后测试上传音频

---

## 📊 Mock 数据说明

### Mock 任务列表

当前 Mock 数据包含 **5 个任务**：

1. **Q1预算撕逼会**（今天，2小时前）
   - 状态：已归档
   - 情绪分数：60
   - 说话人：3人
   - 标签：#PUA预警 #急躁 #画饼

2. **晨间站会**（今天，5小时前）
   - 状态：已归档
   - 情绪分数：75
   - 说话人：5人
   - 标签：#正常 #进度汇报

3. **产品需求评审**（今天，8小时前）
   - 状态：分析中
   - 情绪分数：无（分析中）
   - 说话人：无（分析中）
   - 标签：#争论 #需求变更

4. **周会**（昨天）
   - 状态：已归档
   - 情绪分数：80
   - 说话人：8人
   - 标签：#周报 #计划

5. **技术方案讨论**（前天）
   - 状态：已归档
   - 情绪分数：85
   - 说话人：4人
   - 标签：#技术 #方案

### Mock 上传响应

上传音频后，会返回：
- `sessionId`: 随机生成的 UUID
- `status`: "analyzing"（分析中）
- `estimatedDuration`: 300 秒（5分钟）

---

## 🔍 调试技巧

### 查看日志

在 Xcode 控制台中，你会看到：
- `📦 [Mock] 使用 Mock 数据获取任务列表` - 使用 Mock 数据
- `🌐 [Real] 使用真实 API 获取任务列表` - 使用真实 API

### 检查当前环境

在代码中添加：
```swift
print("当前环境: \(AppConfig.shared.useMockData ? "Mock" : "Real")")
```

---

## ✅ 检查清单

### 文件检查

- [ ] `Shared/AppConfig.swift` 已添加到项目
- [ ] `Services/MockNetworkService.swift` 已添加到项目
- [ ] `Services/NetworkManager.swift` 已更新

### 功能检查

- [ ] 运行项目，能看到 Mock 任务列表
- [ ] 任务卡片显示正常
- [ ] 可以点击任务查看详情
- [ ] 录制按钮可以点击
- [ ] 上传音频返回 Mock 响应

### 代码检查

- [ ] 没有编译错误
- [ ] 没有运行时错误
- [ ] 控制台有正确的日志输出

---

## 🆘 常见问题

### 问题 1: 看不到 Mock 数据

**原因**：文件没有正确添加到项目

**解决**：
1. 检查文件是否在项目导航器中（蓝色图标）
2. 检查文件是否添加到 Target（选中文件，查看右侧面板的 Target Membership）

### 问题 2: 编译错误

**原因**：可能缺少导入或类型不匹配

**解决**：
1. 清理项目：`Product` → `Clean Build Folder`（`Shift + Cmd + K`）
2. 重新编译：`Cmd + B`
3. 查看具体错误信息

### 问题 3: Mock 数据格式不对

**原因**：Task 模型和 Mock 数据不匹配

**解决**：
1. 检查 `Task.swift` 中的字段
2. 检查 `MockNetworkService.swift` 中的 JSON 格式
3. 确保日期格式是 ISO8601

---

## 🎯 下一步

1. **先测试 Mock 数据**：确保 UI 和交互正常
2. **修复所有 Bug**：在 Mock 数据阶段修复问题
3. **逐步切换到真实 API**：一点一点测试

---

**现在可以开始测试了！运行项目，应该能看到 Mock 任务列表。**

