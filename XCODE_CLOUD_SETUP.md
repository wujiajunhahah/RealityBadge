# Xcode Cloud 配置指南

## 项目信息
- **App 名称**: RealityBadge
- **Bundle ID**: `com.wujiajun.RealityBadge`
- **Apple ID**: 6752278083
- **开发团队**: M4T239BM58

## API 密钥信息（已配置）
- **Issuer ID**: `3d8a8ce3-ad11-4ead-9e6c-38eecfe55269`
- **Key ID**: `8399F524UX`
- **密钥文件**: `~/.appstoreconnect/private_keys/AuthKey_8399F524UX.p8`

---

## 配置步骤

### 方法一：通过 Xcode 配置（推荐）

1. **打开项目**
   ```bash
   open RealityBadge.xcodeproj
   ```

2. **创建 Xcode Cloud Workflow**
   - 在 Xcode 菜单栏选择：**Product → Xcode Cloud → Create Workflow**
   - 或者按快捷键：**⌘ + Shift + <**

3. **连接 Git 仓库**
   - 选择 **GitHub**
   - 选择 **RealityBadge** 仓库
   - Xcode Cloud 会自动检测到你的仓库配置

4. **配置 Workflow**
   - **Workflow 名称**: `Main Workflow`（或自定义）
   - **分支**: `main`
   - **构建配置**: `Release`

5. **选择产品**
   - 会自动检测到 `RealityBadge` app
   - 确认 Bundle ID 为 `com.wujiajun.RealityBadge`

6. **配置构建选项**
   - ✅ **Build** - 编译应用
   - ✅ **Test** - 运行单元测试（如果有）
   - ✅ **Analyze** - 代码分析
   - ✅ **Archive** - 生成归档
   - ✅ **Distribute** - 分发到 TestFlight/App Store

7. **配置环境变量**（可选）
   - 在 Environment 中添加需要的环境变量

8. **创建并运行**
   - 点击 **Create Workflow**
   - 首次运行可能需要几分钟

---

### 方法二：通过 App Store Connect 网页配置

1. 访问：https://appstoreconnect.apple.com
2. 选择 **RealityBadge** app
3. 左侧菜单选择 **TestFlight → Xcode Cloud**
4. 点击 **+** 创建 Workflow
5. 按照向导完成配置

---

## 常见问题

### Q: 首次运行失败？
**A:** 检查以下配置：
- Development Team ID 是否正确（M4T239BM58）
- Bundle ID 是否与 App Store Connect 一致
- 代码签名证书是否有效

### Q: 如何配置自动化测试？
**A:** 在项目的 Test Target 中添加测试用例，Xcode Cloud 会自动运行

### Q: 如何配置 TestFlight 自动分发？
**A:** 在 Workflow 设置中启用 "Distribute to TestFlight"

### Q: 如何配置 App Store 自动提交？
**A:** 在 Workflow 设置中启用 "Distribute to App Store Connect"

---

## Workflow 模板

### 开发分支 Workflow
```
名称: Development
分支: dev/*
触发: 每次 push
操作: Build + Test
```

### 发布分支 Workflow
```
名称: Release
分支: main/release
触发: 手动触发
操作: Build + Test + Archive + Distribute to TestFlight
```

### 主分支 Workflow
```
名称: Main
分支: main
触发: 每次 push
操作: Build + Test + Analyze + Archive
```

---

## 下一步

1. 在 Xcode 中创建第一个 Workflow
2. 测试构建是否成功
3. 配置通知（Email/Slack/Discord）
4. 设置自动发布到 TestFlight

---

*配置完成时间: 2026-03-17*
