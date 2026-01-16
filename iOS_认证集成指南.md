# iOS客户端认证集成指南

## 概述

本文档说明如何在iOS客户端中集成用户认证系统，包括登录页面、Token存储和自动添加认证Header。

## 已创建的文件

### 1. KeychainManager.swift
- **功能**: 使用Keychain安全存储JWT Token和用户ID
- **位置**: `iOS_Code_Files/KeychainManager.swift`
- **主要方法**:
  - `saveToken(_:)` - 保存Token
  - `getToken()` - 获取Token
  - `deleteToken()` - 删除Token
  - `isLoggedIn()` - 检查是否已登录

### 2. AuthService.swift
- **功能**: 处理认证相关的API调用
- **位置**: `iOS_Code_Files/AuthService.swift`
- **主要方法**:
  - `sendVerificationCode(phone:)` - 发送验证码
  - `login(phone:code:)` - 登录
  - `getCurrentUser()` - 获取当前用户信息
  - `logout()` - 登出

### 3. AuthManager.swift
- **功能**: 管理全局登录状态
- **位置**: `iOS_Code_Files/AuthManager.swift`
- **特性**: 使用`@Published`属性，支持SwiftUI响应式更新

### 4. AuthViewModel.swift
- **功能**: 登录页面的ViewModel
- **位置**: `iOS_Code_Files/AuthViewModel.swift`
- **功能**:
  - 手机号和验证码输入验证
  - 发送验证码（带60秒倒计时）
  - 登录处理
  - 错误提示

### 5. LoginView.swift
- **功能**: 登录页面UI
- **位置**: `iOS_Code_Files/LoginView.swift`
- **UI特性**:
  - 手机号输入（11位数字限制）
  - 验证码输入（6位数字限制）
  - 发送验证码按钮（带倒计时）
  - 登录按钮（带加载状态）
  - 错误提示弹窗

## 已修改的文件

### 1. NetworkManager.swift
- **修改内容**: 将`getAuthToken()`方法改为从Keychain读取Token
- **位置**: `NetworkManager.swift` 和 `iOS_Code_Files/NetworkManager.swift`
- **变更**:
  ```swift
  // 修改前
  private func getAuthToken() -> String {
      return UserDefaults.standard.string(forKey: "auth_token") ?? ""
  }
  
  // 修改后
  private func getAuthToken() -> String {
      return KeychainManager.shared.getToken() ?? ""
  }
  ```

### 2. ContentView.swift
- **修改内容**: 添加登录状态检查，未登录时显示登录页面
- **位置**: `iOS_Code_Files/ContentView.swift`
- **变更**: 添加了`AuthManager`状态管理和登录检查逻辑

## 集成步骤

### 1. 在Xcode中添加文件

1. 打开Xcode项目
2. 将以下文件添加到项目中：
   - `KeychainManager.swift`
   - `AuthService.swift`
   - `AuthManager.swift`
   - `AuthViewModel.swift`
   - `LoginView.swift`

3. 确保文件已添加到Target（在File Inspector中勾选Target Membership）

### 2. 添加Security框架

Keychain功能需要Security框架，通常已自动链接。如果遇到编译错误，请检查：
- Project Settings → General → Frameworks, Libraries, and Embedded Content
- 确保Security.framework已添加

### 3. 确保Alamofire已添加

认证服务使用Alamofire进行网络请求，确保已通过SPM或CocoaPods添加。

### 4. 测试登录流程

1. 运行应用
2. 应该首先看到登录页面
3. 输入11位手机号（例如：13800138000）
4. 点击"发送验证码"
5. 输入验证码（开发阶段使用：123456）
6. 点击"登录"
7. 登录成功后应自动跳转到主界面

## API端点

### 发送验证码
- **URL**: `POST /api/v1/auth/send-code`
- **请求体**: `{"phone": "13800138000"}`
- **响应**: `{"code": 200, "message": "验证码已发送", "data": {"phone": "13800138000", "code": "123456"}}`

### 登录
- **URL**: `POST /api/v1/auth/login`
- **请求体**: `{"phone": "13800138000", "code": "123456"}`
- **响应**: `{"code": 200, "message": "登录成功", "data": {"token": "...", "user_id": "...", "expires_in": 86400}}`

### 获取用户信息
- **URL**: `GET /api/v1/auth/me`
- **Header**: `Authorization: Bearer {token}`
- **响应**: `{"code": 200, "message": "获取成功", "data": {"user_id": "...", "phone": "...", "created_at": "...", "last_login_at": "..."}}`

## 安全特性

### 1. Keychain存储
- Token存储在iOS Keychain中，比UserDefaults更安全
- 即使应用被卸载，Keychain中的数据也会保留（除非手动清除）

### 2. 自动Token验证
- 所有需要认证的API请求自动添加`Authorization: Bearer {token}` Header
- Token过期时，`AuthManager`会自动清除登录状态

### 3. 登录状态管理
- 应用启动时自动检查登录状态
- 如果Token有效，自动加载用户信息
- 如果Token无效或过期，自动跳转到登录页面

## 开发阶段配置

### 验证码
- 开发阶段使用固定验证码：`123456`
- 所有手机号都可以使用此验证码登录
- 生产环境需要集成真实的短信服务

### API地址
- 当前配置：`http://47.79.254.213:8001/api/v1`
- 如需修改，请更新`AuthService.swift`和`NetworkManager.swift`中的`baseURL`

## 常见问题

### 1. 登录后仍然显示登录页面
- 检查`AuthManager.shared.isLoggedIn`的值
- 确认Token已成功保存到Keychain
- 查看控制台日志，检查是否有错误

### 2. API请求返回401
- 检查Token是否正确保存
- 确认Token未过期（默认24小时）
- 检查NetworkManager是否正确添加Authorization Header

### 3. 验证码发送失败
- 检查网络连接
- 确认API地址正确
- 查看控制台错误信息

## 下一步

1. **添加登出功能**: 在"我的"页面添加登出按钮
2. **Token刷新**: 实现Token自动刷新机制
3. **用户信息显示**: 在"我的"页面显示用户信息
4. **生产环境配置**: 集成真实短信服务

## 文件清单

```
iOS_Code_Files/
├── KeychainManager.swift      # Keychain管理
├── AuthService.swift          # 认证服务
├── AuthManager.swift          # 认证状态管理
├── AuthViewModel.swift        # 登录ViewModel
├── LoginView.swift            # 登录页面
├── NetworkManager.swift       # 网络管理器（已更新）
└── ContentView.swift           # 主视图（已更新）
```

## 测试清单

- [ ] 登录页面正常显示
- [ ] 手机号输入限制（11位数字）
- [ ] 验证码输入限制（6位数字）
- [ ] 发送验证码功能正常
- [ ] 验证码倒计时正常
- [ ] 登录功能正常
- [ ] Token正确保存到Keychain
- [ ] 登录后自动跳转到主界面
- [ ] API请求自动添加Authorization Header
- [ ] Token过期时自动跳转到登录页面
