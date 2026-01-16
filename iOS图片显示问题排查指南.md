# iOS 图片显示问题排查指南

## 常见问题及解决方案

### 1. 图片不显示 - baseURL 配置错误

**问题**: NetworkManager 的 baseURL 设置为 `localhost`，iOS 设备无法访问。

**解决方案**:
1. 打开 `NetworkManager.swift`
2. 将 `baseURL` 修改为实际的服务器地址：
   ```swift
   private let baseURL = "http://47.79.254.213:8001/api/v1"
   ```

### 2. 图片不显示 - URL 转换失败

**问题**: OSS URL 没有正确转换为后端 API URL。

**排查步骤**:
1. 查看 Xcode 控制台日志，查找 `[VisualData]` 和 `[ImageLoaderView]` 的日志
2. 检查原始 URL 和转换后的 URL
3. 确认 baseURL 是否正确传递

**日志示例**:
```
🔄 [VisualData] 转换图片 URL:
  原始 URL: https://geminipicture2.oss-cn-beijing.aliyuncs.com/images/xxx/0.png
  baseURL: http://47.79.254.213:8001/api/v1
✅ [VisualData] OSS URL 转换成功:
  转换后 URL: http://47.79.254.213:8001/api/v1/images/xxx/0
```

### 3. 图片不显示 - 网络请求失败

**问题**: 无法访问后端 API。

**排查步骤**:
1. 检查 Xcode 控制台的 HTTP 状态码
2. 确认设备可以访问服务器（ping 或浏览器测试）
3. 检查 Info.plist 中的网络权限配置

**日志示例**:
```
📡 [ImageLoaderView] HTTP 状态码: 200  // 成功
📡 [ImageLoaderView] HTTP 状态码: 404  // 图片不存在
📡 [ImageLoaderView] HTTP 状态码: 500  // 服务器错误
```

### 4. 图片不显示 - 数据解析失败

**问题**: 返回的数据格式不正确。

**排查步骤**:
1. 检查策略分析接口返回的数据结构
2. 确认 `visual` 数组是否包含数据
3. 确认 `image_url` 字段是否存在

**调试代码**:
```swift
// 在 StrategyAnalysisView_Updated 的 loadStrategyAnalysis 方法中添加
print("📊 [StrategyAnalysis] 收到数据:")
print("  关键时刻数量: \(response.visual.count)")
for (index, visual) in response.visual.enumerated() {
    print("  关键时刻 \(index):")
    print("    imageUrl: \(visual.imageUrl ?? "nil")")
    print("    imageBase64: \(visual.imageBase64 != nil ? "有数据" : "nil")")
}
```

### 5. 图片不显示 - Info.plist 配置问题

**问题**: iOS 不允许 HTTP 请求（需要 HTTPS 或配置 ATS）。

**解决方案**:
在 `Info.plist` 中添加：
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

或者只允许特定域名：
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>47.79.254.213</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

## 调试步骤

### 步骤 1: 检查数据是否正确返回

在 Xcode 控制台查看日志：
```
📊 [StrategyAnalysis] 收到数据:
  关键时刻数量: 3
  关键时刻 0:
    imageUrl: https://geminipicture2.oss-cn-beijing.aliyuncs.com/images/xxx/0.png
    imageBase64: nil
```

### 步骤 2: 检查 URL 转换

查看 URL 转换日志：
```
🔄 [VisualData] 转换图片 URL:
  原始 URL: https://geminipicture2.oss-cn-beijing.aliyuncs.com/images/xxx/0.png
  baseURL: http://47.79.254.213:8001/api/v1
✅ [VisualData] OSS URL 转换成功:
  转换后 URL: http://47.79.254.213:8001/api/v1/images/xxx/0
```

### 步骤 3: 检查图片加载

查看图片加载日志：
```
🖼️ [ImageLoaderView] 开始加载图片: http://47.79.254.213:8001/api/v1/images/xxx/0
📡 [ImageLoaderView] HTTP 状态码: 200
✅ [ImageLoaderView] 收到数据，大小: 1379114 字节
✅ [ImageLoaderView] 图片加载成功，尺寸: (1184.0, 864.0)
```

### 步骤 4: 手动测试 API

在浏览器或 Postman 中测试：
```
GET http://47.79.254.213:8001/api/v1/images/{session_id}/0
```

应该返回 PNG 图片数据。

## 常见错误信息

### 错误 1: "无效的 URL"
- **原因**: URL 字符串格式不正确
- **解决**: 检查 URL 转换逻辑，确认生成的 URL 格式正确

### 错误 2: "HTTP 404"
- **原因**: 图片不存在或 session_id 错误
- **解决**: 确认 session_id 正确，检查后端日志

### 错误 3: "HTTP 500"
- **原因**: 服务器内部错误
- **解决**: 检查后端服务状态和日志

### 错误 4: "无法解析图片数据"
- **原因**: 返回的数据不是有效的图片格式
- **解决**: 检查后端返回的 Content-Type 是否为 `image/png`

## 快速修复清单

- [ ] 确认 `NetworkManager.baseURL` 不是 `localhost`
- [ ] 确认 `Info.plist` 配置了网络权限
- [ ] 查看 Xcode 控制台日志，确认 URL 转换正确
- [ ] 手动测试图片 API 是否可以访问
- [ ] 确认策略分析接口返回了 `image_url` 字段
- [ ] 检查设备网络连接

## 联系支持

如果问题仍然存在，请提供：
1. Xcode 控制台的完整日志
2. 策略分析接口的响应数据（JSON）
3. 图片 API 的手动测试结果
4. 设备信息（iOS 版本、设备型号）
