# iOS 客户端测试指南

## ✅ 服务器已就绪

- ✅ 后端服务运行在 `http://47.79.254.213:8001`
- ✅ 防火墙已配置，端口 8001 已开放
- ✅ 从 Mac 可以访问服务

## 📱 iOS 客户端测试步骤

### 步骤 1: 确认配置

#### 1.1 检查 `NetworkManager.swift`
确保 `baseURL` 已更新为：
```swift
private let baseURL = "http://47.79.254.213:8001/api/v1"
```

#### 1.2 检查 `AppConfig.swift`
确保使用真实 API（不是 Mock 数据）：

**方法 1: 通过代码设置（推荐）**
```swift
// 在 AppConfig.swift 中
var currentEnvironment: Environment {
    // 强制使用生产环境
    return .production
}
```

**方法 2: 通过 UserDefaults 设置（运行时切换）**
在应用启动时设置：
```swift
// 在 AppDelegate 或 @main 中
AppConfig.shared.setUseMockData(false)
```

### 步骤 2: 运行应用

1. **打开 Xcode**
2. **选择模拟器或真机**
   - 模拟器：选择任意 iOS 16+ 模拟器
   - 真机：连接 iPhone/iPad
3. **运行应用** (`Cmd + R`)

### 步骤 3: 测试完整流程

#### 3.1 查看任务列表
- 应用启动后，应该显示"任务"标签页
- 查看控制台日志，应该看到：
  ```
  🌐 [NetworkManager] ========== 获取任务列表 ==========
  🌐 [NetworkManager] API 地址: http://47.79.254.213:8001/api/v1/tasks/sessions
  ```

#### 3.2 录制音频
1. **点击录制按钮**（右下角浮动按钮）
2. **允许麦克风权限**（首次使用会提示）
3. **开始录制**（说话或播放音频）
4. **查看控制台日志**，应该看到：
   ```
   🎤 [RecordingViewModel] ========== 开始录制 ==========
   🎤 [AudioRecorderService] ========== 开始录音 ==========
   ```

#### 3.3 停止录制并上传
1. **点击停止按钮**
2. **查看控制台日志**，应该看到：
   ```
   🛑 [RecordingViewModel] ========== 停止录制并上传 ==========
   📤 [NetworkManager] ========== 上传音频 ==========
   📤 [NetworkManager] 上传进度: 100%
   ✅ [NetworkManager] 上传成功
   ```

#### 3.4 查看任务创建
- **任务列表应该立即显示新任务**，状态为"分析中"
- **查看控制台日志**，应该看到：
  ```
  📢 [TaskListViewModel] 收到 NewTaskCreated 通知
  ✅ [RecordingViewModel] 真实 API 上传成功，任务创建
  ```

#### 3.5 等待分析完成
- **查看控制台日志**，应该看到轮询状态：
  ```
  🔄 [RecordingViewModel] 启动状态轮询 for session: xxx
  🔄 [RecordingViewModel] 轮询 xxx (第 1/60 次)
  ```
- **分析完成后**，任务状态会变为"已归档"
- **查看控制台日志**，应该看到：
  ```
  ✅ [RecordingViewModel] 任务 xxx 分析完成或失败，获取详情...
  📢 [RecordingViewModel] 发送 TaskAnalysisCompleted 通知
  ```

### 步骤 4: 查看服务器日志（可选）

在服务器上实时查看日志：
```bash
ssh admin@47.79.254.213
tail -f /tmp/gemini-service.log
```

## 🔍 预期结果

### 成功标志

1. **任务列表加载成功**
   - 控制台显示：`✅ [NetworkManager] 获取任务列表成功`

2. **音频上传成功**
   - 控制台显示：`✅ [NetworkManager] 上传成功`
   - 任务列表中出现新任务（状态：分析中）

3. **任务分析完成**
   - 控制台显示：`✅ [RecordingViewModel] 任务分析完成`
   - 任务状态变为"已归档"
   - 可以点击查看详情

### 失败排查

#### 问题 1: 无法获取任务列表
**症状**: 控制台显示连接失败

**检查**:
1. `NetworkManager.swift` 的 `baseURL` 是否正确
2. `AppConfig.swift` 是否设置为生产环境
3. 网络连接是否正常

#### 问题 2: 上传失败
**症状**: 控制台显示上传错误

**检查**:
1. 服务器是否运行：`ps aux | grep python3 | grep main.py`
2. 防火墙是否配置：`curl http://47.79.254.213:8001/health`
3. 查看服务器日志：`tail -f /tmp/gemini-service.log`

#### 问题 3: 任务一直显示"分析中"
**症状**: 任务状态不更新

**检查**:
1. 查看服务器日志，检查 Gemini API 调用是否成功
2. 检查 Gemini API Key 是否正确
3. 查看轮询日志，确认是否在轮询状态

## 📊 完整测试流程检查清单

- [ ] 服务器运行中
- [ ] 防火墙已配置（端口 8001）
- [ ] 从 Mac 可以访问 `http://47.79.254.213:8001/health`
- [ ] iOS 客户端 `NetworkManager.baseURL` 已更新
- [ ] iOS 客户端 `AppConfig` 设置为生产环境
- [ ] 应用可以启动
- [ ] 任务列表可以加载
- [ ] 可以录制音频
- [ ] 可以上传音频
- [ ] 任务列表显示新任务
- [ ] 任务状态从"分析中"变为"已归档"
- [ ] 可以查看任务详情

## 🎉 完成！

如果所有步骤都成功，恭喜你！整个系统已经可以正常工作了：

1. ✅ iOS 客户端可以录制音频
2. ✅ 音频可以上传到服务器
3. ✅ 服务器使用 Gemini API 分析音频
4. ✅ 分析结果返回并显示在 iOS 客户端

现在你可以开始使用完整的音频分析功能了！


