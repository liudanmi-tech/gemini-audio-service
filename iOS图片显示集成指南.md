# iOS 客户端图片显示集成指南

## 概述

本指南说明如何在 iOS 客户端集成图片显示功能，包括关键时刻的图片轮播和策略分析视图。

## 已创建的文件

1. **VisualData.swift** - 数据模型
   - `VisualData`: 关键时刻数据模型
   - `StrategyAnalysisResponse`: 策略分析响应模型
   - `StrategyItem`: 策略项模型

2. **NetworkManager.swift** - 网络请求（已更新）
   - 添加了 `getStrategyAnalysis(sessionId:)` 方法
   - 添加了 `VisualData` 扩展，包含 `getAccessibleImageURL()` 方法

3. **ImageLoaderView.swift** - 图片加载组件
   - 支持从 URL 或 Base64 加载图片
   - 自动处理加载状态和错误

4. **VisualMomentCarouselView.swift** - 关键时刻图片轮播组件
   - 支持左右滑动查看多张图片
   - 显示页码指示器

5. **StrategyAnalysisView_Updated.swift** - 更新后的策略分析视图
   - 集成图片轮播
   - 显示策略列表

## 集成步骤

### 1. 将文件添加到 Xcode 项目

将所有新创建的 Swift 文件添加到 Xcode 项目：

```
iOS_Code_Files/
├── VisualData.swift
├── ImageLoaderView.swift
├── VisualMomentCarouselView.swift
└── StrategyAnalysisView_Updated.swift
```

### 2. 更新 NetworkManager 的 baseURL

在 `NetworkManager.swift` 中，确保 `baseURL` 指向正确的服务器地址：

```swift
private let baseURL = "http://47.79.254.213:8001/api/v1"  // 或你的服务器地址
```

### 3. 使用策略分析视图

在需要显示策略分析的页面中，使用 `StrategyAnalysisView_Updated`：

```swift
import SwiftUI

struct YourView: View {
    let sessionId: String
    
    var body: some View {
        StrategyAnalysisView_Updated(
            sessionId: sessionId,
            baseURL: "http://47.79.254.213:8001/api/v1"  // 与 NetworkManager 中的 baseURL 保持一致
        )
    }
}
```

### 4. 单独使用图片轮播组件

如果只需要显示关键时刻图片，可以使用 `VisualMomentCarouselView`：

```swift
VisualMomentCarouselView(
    visualMoments: visualDataArray,  // [VisualData] 数组
    baseURL: "http://47.79.254.213:8001/api/v1"
)
```

### 5. 单独使用图片加载组件

如果需要单独加载图片，可以使用 `ImageLoaderView`：

```swift
ImageLoaderView(
    imageUrl: "http://47.79.254.213:8001/api/v1/images/\(sessionId)/0",
    imageBase64: nil,
    placeholder: "加载中..."
)
```

## 图片 URL 转换说明

由于 OSS bucket 设置为私有，不能直接访问 OSS URL。系统会自动将 OSS URL 转换为后端 API URL：

- **OSS URL**: `https://geminipicture2.oss-cn-beijing.aliyuncs.com/images/{session_id}/{image_index}.png`
- **后端 API URL**: `http://47.79.254.213:8001/api/v1/images/{session_id}/{image_index}`

转换逻辑在 `VisualData.getAccessibleImageURL()` 方法中实现。

## API 调用流程

1. **上传音频** → 获取 `session_id`
2. **调用策略分析接口** → `POST /api/v1/tasks/sessions/{session_id}/strategies`
3. **返回数据**：
   ```json
   {
     "code": 200,
     "data": {
       "visual": [
         {
           "transcript_index": 0,
           "speaker": "Speaker_0",
           "emotion": "强压、支配",
           "image_url": "https://geminipicture2.oss-cn-beijing.aliyuncs.com/images/.../0.png",
           ...
         }
       ],
       "strategies": [...]
     }
   }
   ```
4. **显示图片** → 使用转换后的后端 API URL 加载图片

## 功能特性

### 图片轮播
- ✅ 支持左右滑动查看多张图片
- ✅ 显示页码指示器（第 X/总数）
- ✅ 自动处理加载状态
- ✅ 错误处理和占位符

### 图片加载
- ✅ 支持 URL 和 Base64 两种方式
- ✅ 自动重试机制
- ✅ 加载状态提示
- ✅ 错误提示

### 策略分析
- ✅ 显示关键时刻图片
- ✅ 显示策略列表
- ✅ 可展开/收起策略详情
- ✅ 加载状态和错误处理

## 注意事项

1. **网络权限**: 确保在 `Info.plist` 中配置了网络权限：
   ```xml
   <key>NSAppTransportSecurity</key>
   <dict>
       <key>NSAllowsArbitraryLoads</key>
       <true/>
   </dict>
   ```

2. **baseURL 配置**: 确保 `NetworkManager` 和视图中的 `baseURL` 保持一致。

3. **图片缓存**: 当前实现不包含图片缓存，每次都会重新加载。如需缓存，可以使用 `SDWebImage` 或 `Kingfisher` 等第三方库。

4. **错误处理**: 如果图片加载失败，会显示错误提示。可以根据需要自定义错误处理逻辑。

## 测试

1. 上传音频文件，获取 `session_id`
2. 调用策略分析接口
3. 检查返回的 `visual` 数组是否包含 `image_url`
4. 在客户端查看图片是否正确显示
5. 测试左右滑动功能

## 故障排查

### 图片无法显示

1. **检查 URL**: 确认 `image_url` 是否正确
2. **检查网络**: 确认设备可以访问服务器
3. **检查后端 API**: 访问 `http://47.79.254.213:8001/api/v1/images/{session_id}/{image_index}` 查看是否返回图片
4. **查看日志**: 检查 Xcode 控制台的错误信息

### 策略分析加载失败

1. **检查 session_id**: 确认 `session_id` 是否有效
2. **检查网络连接**: 确认设备可以访问服务器
3. **检查后端服务**: 确认后端服务正常运行
4. **查看错误信息**: 检查返回的错误消息

## 后续优化建议

1. **图片缓存**: 使用第三方库实现图片缓存
2. **预加载**: 预加载下一张图片，提升用户体验
3. **图片压缩**: 如果图片过大，可以在后端进行压缩
4. **CDN 加速**: 如果使用 CDN，可以配置 CDN URL
5. **占位图**: 使用更美观的占位图
