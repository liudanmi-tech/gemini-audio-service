# iOS 配置 ATS 允许 HTTP 连接

## 问题
iOS 的 App Transport Security (ATS) 策略默认要求使用 HTTPS 连接。如果使用 HTTP 地址，会出现以下错误：
```
The resource could not be loaded because the App Transport Security policy requires the use of a secure connection.
```

## 解决方案

### 方法 1: 通过 Xcode 项目设置（推荐）

1. **打开 Xcode 项目**
2. **在项目导航器中，点击项目名称（蓝色图标）**
3. **选择 Target "WorkSurvivalGuide"**
4. **点击 "Info" 标签**
5. **找到 "App Transport Security Settings"**（如果没有，点击 "+" 添加）
6. **展开 "App Transport Security Settings"**
7. **点击 "+" 添加 "Exception Domains"**
8. **添加以下配置**：
   - **Key**: `NSAppTransportSecurity`
   - **Type**: Dictionary
   - **Value**: 
     - 添加子项 `NSExceptionDomains`
     - **Type**: Dictionary
     - **Value**:
       - 添加子项 `47.79.254.213`
       - **Type**: Dictionary
       - **Value**:
         - `NSExceptionAllowsInsecureHTTPLoads`: `YES` (Boolean)
         - `NSIncludesSubdomains`: `YES` (Boolean)

### 方法 2: 直接编辑 Info.plist（如果方法 1 不行）

1. **在项目导航器中找到 `Info.plist`**
2. **右键点击，选择 "Open As" → "Source Code"**
3. **在 `</dict>` 标签之前添加以下内容**：

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

### 方法 3: 完全禁用 ATS（不推荐，仅用于开发）

如果上述方法都不行，可以完全禁用 ATS（仅用于开发测试）：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

⚠️ **警告**: 方法 3 会允许所有 HTTP 连接，存在安全风险，仅用于开发测试。

---

## 验证配置

配置完成后：
1. **清理构建**（`Cmd + Shift + K`）
2. **重新构建**（`Cmd + B`）
3. **运行应用**（`Cmd + R`）
4. **测试录制和上传功能**

如果配置成功，应该不再出现 ATS 错误。

---

## 生产环境建议

在生产环境中，应该：
1. **使用 HTTPS**（配置 SSL 证书）
2. **移除 ATS 例外配置**
3. **确保所有 API 调用都使用 HTTPS**


