# Xcode Cloud 配置操作指南

## 📍 当前位置

你在 Xcode 中，准备创建 Xcode Cloud Workflow

---

## 第一步：打开 Workflow 创建

在 Xcode 菜单栏：
```
Product → Xcode Cloud → Create Workflow
```

---

## 第二步：选择仓库

1. 代码提供商选择：**GitHub**
2. 仓库选择：**RealityBadge**
3. 点击 **Continue**

---

## 第三步：配置工作流

### 基本信息
| 选项 | 值 |
|------|-----|
| Workflow 名称 | `Main Workflow` |
| 分支 | `main` |
| 方案 | `RealityBadge` |
| 配置 | `Release` |

### 构建操作
勾选以下选项：
- ✅ **Build** (必需)
- ✅ **Run Tests** (如果有测试)
- ✅ **Analyze** (推荐)
- ✅ **Archive** (必需)

---

## 第四步：配置 TestFlight 自动分发

### 启用 TestFlight 分发

在 "Distribute" 部分找到 **TestFlight**：

1. ✅ 勾选 **Distribute to TestFlight**
2. ✅ 勾选 **Automatically Distribute**
3. 设置 **自动分发版本**: `Latest Build`
4. ✅ 勾选 **Notify Testers**

### 测试组设置
```
Internal Testers (默认启用)
- 你和团队成员会自动收到通知

External Testers (可选)
- 需要审核，可以稍后添加
```

### 变更日志
```
使用默认模板或输入：
"测试新功能和改进"
```

---

## 第五步：配置 App Store 自动提交

### ⚠️ 当前阶段：暂时禁用

**注意**：App Store 自动提交应该在应用准备正式发布时再启用。

现在：
- ⏸️ **不要勾选** "Distribute to App Store"

### 准备发布时如何启用：

1. 编辑现有 Workflow
2. 在 "Distribute" 部分找到 **App Store**
3. ✅ 勾选 **Distribute to App Store**
4. ✅ 勾选 **Automatically Submit for Review**
5. 选择版本策略：**Same as TestFlight**

---

## 第六步：创建 Workflow

点击 **Create** 按钮

首次构建将自动开始 🚀

---

## 🎯 配置完成后的效果

### 正常流程（当前）
```
Push 到 main
  → Build
  → Test
  → Archive
  → TestFlight ✅ (自动分发)
```

### 发布流程（将来）
```
发布版本
  → Build
  → Test
  → Archive
  → TestFlight ✅
  → App Store ✅ (自动提交审核)
```

---

## 📋 配置检查清单

完成后检查：
- [ ] Workflow 已创建
- [ ] 首次构建成功
- [ ] TestFlight 分发已启用
- [ ] 你收到了 TestFlight 邀请邮件
- [ ] 可以在 App Store Connect 看到构建版本

---

## ❓ 遇到问题？

### 构建失败
1. 检查代码签名配置
2. 确认 Bundle ID 正确
3. 查看构建日志

### TestFlight 没有收到通知
1. 检查邮件设置
2. 确认你在 Internal Testers 列表中
3. 等待几分钟（可能需要时间）

---

开始配置吧！有任何问题随时告诉我。
