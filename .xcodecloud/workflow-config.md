# Xcode Cloud Workflow 配置清单

## ✅ 基础配置
- [x] 分支: main
- [x] 构建配置: Release
- [x] 产品: RealityBadge
- [x] Bundle ID: com.wujiajun.RealityBadge

---

## 📱 TestFlight 配置

### 自动分发设置
```
✅ Distribute to TestFlight: 启用
✅ Automatically Distribute: 启用
✅ Notify Testers: 启用
```

### 测试组配置
| 组别 | 说明 |
|------|------|
| Internal Testers | 内部测试（最多 100 人） |
| External Testgers | 外部测试（需审核） |

### 分发频率
- **推荐**: 每次构建成功后自动分发
- **备选**: 手动触发发布

### 版本号策略
```
TestFlight: 1.0.x (每次构建 +1)
```

---

## 🏪 App Store 配置

### 自动提交设置（发布时启用）
```
⏸️ Distribute to App Store: 暂时禁用
✅ 准备就绪时启用
```

### 提交前检查清单
- [ ] 应用图标完整
- [ ] 截图准备就绪
- [ ] 应用描述完成
- [ ] 分级评定完成
- [ ] 隐私政策 URL
- [ ] 审核信息完整

### 启用步骤
1. 在 Workflow 编辑中找到 "Distribute" 部分
2. 启用 "App Store Connect"
3. 选择 "Automatically Submit for Review"
4. 配置版本号策略

---

## 🔔 通知配置

### 推荐通知方式
- ✅ Email（项目成员）
- ⏸️ Slack/Discord（可选）

### 通知事件
- 构建开始
- 构建成功
- 构建失败
- 测试完成
- 发布成功

---

## 📊 工作流程图

```
┌─────────────┐
│ Push to main│
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Build     │  ← 编译应用
└──────┬──────┘
       │
       ▼
┌─────────────┐
│    Test     │  ← 运行测试（如有）
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Analyze   │  ← 代码分析
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Archive   │  ← 生成归档
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ TestFlight  │  ← 自动分发测试
└──────┬──────┘
       │
       ▼ (发布时)
┌─────────────┐
│ App Store   │  ← 提交审核
└─────────────┘
```

---

## 🎯 当前阶段建议

### 开发测试阶段
```
✅ TestFlight: 自动分发
⏸️ App Store: 禁用
```

### 准备发布阶段
```
✅ TestFlight: 自动分发
✅ App Store: 启用自动提交
```

---

## 📝 下一步

1. **在 Xcode 中创建 Workflow**
2. **启用 TestFlight 自动分发**
3. **首次构建测试**
4. **邀请内部测试人员**
5. **收集反馈并迭代**

---

*配置时间: 2026-03-17*
*Bundle ID: com.wujiajun.RealityBadge*
*Apple ID: 6752278083*
