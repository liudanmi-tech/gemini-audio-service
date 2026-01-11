# iOS 快速开始指南

## 🚀 5 分钟快速开始

### 第一步：安装 Xcode
1. 打开 Mac 的 App Store
2. 搜索 "Xcode" 并安装（约 10GB，需要一些时间）

### 第二步：创建项目
1. 打开 Xcode
2. `File` → `New` → `Project`
3. 选择 **iOS** → **App** → `Next`
4. 填写：
   - Product Name: `WorkSurvivalGuide`
   - Interface: `SwiftUI`
   - Language: `Swift`
5. 选择保存位置 → `Create`

### 第三步：配置项目
1. 点击项目名称（蓝色图标）→ 选择 Target → `General`
2. 设置 **Deployment Target** 为 `iOS 16.0`
3. 打开 `Info.plist`，添加一行：
   - Key: `Privacy - Microphone Usage Description`
   - Value: `需要访问麦克风以录制会议音频`

### 第四步：添加 Alamofire
1. 点击项目名称 → `Package Dependencies` 标签
2. 点击 `+` 按钮
3. 输入：`https://github.com/Alamofire/Alamofire.git`
4. 选择版本 `5.8.0` → `Add Package`

### 第五步：创建文件夹
在项目导航器中，右键点击 `WorkSurvivalGuide` 文件夹，创建以下结构：
```
WorkSurvivalGuide/
├── TaskModule/
│   ├── Views/
│   ├── ViewModels/
│   ├── Models/
│   └── Services/
└── Shared/
    ├── Models/
    └── Utilities/
```

### 第六步：复制代码文件
按照 `iOS_DEVELOPMENT_GUIDE.md` 中的步骤，逐个创建文件并复制代码。

### 第七步：运行
1. 选择模拟器（顶部工具栏）
2. 点击 ▶ 按钮运行
3. 测试录音功能

---

## 📝 开发顺序建议

1. ✅ **数据模型**（Task.swift, APIResponse.swift）
2. ✅ **网络服务**（NetworkManager.swift）
3. ✅ **录音服务**（AudioRecorderService.swift）
4. ✅ **ViewModel**（TaskListViewModel.swift, RecordingViewModel.swift）
5. ✅ **视图组件**（TaskCardView.swift, RecordingButtonView.swift）
6. ✅ **主视图**（TaskListView.swift）
7. ✅ **更新 ContentView**

---

## ⚠️ 重要提示

1. **后端 API 地址**: 在 `NetworkManager.swift` 中修改 `baseURL` 为你的后端地址
2. **首次运行**: 需要在模拟器中允许麦克风权限
3. **编译错误**: 检查所有文件是否都添加到项目中（项目导航器中应该有蓝色图标）

---

## 🆘 遇到问题？

查看 `iOS_DEVELOPMENT_GUIDE.md` 中的"常见问题"部分，或查看 Xcode 控制台的错误信息。


