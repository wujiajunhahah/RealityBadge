# 🚀 RealityBadge App Store 上线指南

## 📋 上线前检查清单

### ✅ 已完成项目
- [x] Bundle ID 更新为 `com.wujiajun.RealityBadge231`
- [x] 应用显示名称更新为 "RealityBadge"  
- [x] 应用图标已添加（完整尺寸集合）
- [x] 权限说明文本符合App Store要求
- [x] 创建App Store专用构建脚本

### 🛠️ 立即执行步骤

#### 1. 构建App Store版本
```bash
cd /Users/wujiajun/Downloads/RealityBadge

# 设置你的Apple Team ID [[memory:8097932]]
export TEAM_ID=M4T239BM58

# 执行App Store构建
./scripts/build_for_appstore.sh
```

#### 2. 上传到App Store Connect
1. 打开 Xcode
2. 菜单：Window → Organizer
3. 在Archives标签页中选择刚才创建的RealityBadge Archive
4. 点击 "Distribute App"
5. 选择 "App Store Connect"
6. 选择适当的导出选项（通常选择默认）
7. 等待上传完成

#### 3. 在App Store Connect中配置应用

访问 [App Store Connect](https://appstoreconnect.apple.com)：

**应用基本信息：**
- 应用名称：RealityBadge  
- 副标题：增强现实徽章生成器
- 类别：照片与视频 / 生产力工具
- 年龄分级：4+ 

**应用描述（建议）：**
```
RealityBadge 是一款创新的增强现实应用，让您轻松创建个性化的虚拟徽章。

🌟 主要功能：
• 实时相机取景，创建独特徽章
• 先进的主体识别技术
• 3D视差效果，增强视觉体验
• 支持多种徽章样式和效果
• 简洁直观的用户界面

📱 技术特色：
• 利用最新的iOS Vision框架
• 流畅的增强现实体验
• 高质量图像处理
• 支持iPad和iPhone

无论是个人收藏、社交分享还是创意表达，RealityBadge都是您的理想选择！
```

**关键词：**
增强现实,AR,徽章,相机,照片,创意,Vision,3D,个性化,分享

**应用截图要求：**
- iPhone: 6.7", 6.5", 5.5" 屏幕尺寸各3-10张
- iPad: 12.9", 11" 屏幕尺寸各3-10张

#### 4. 应用截图准备
建议截图内容：
1. 主界面展示
2. 相机取景界面
3. 徽章创建过程
4. 3D效果展示
5. 设置界面

#### 5. 版本发布信息
**版本：** 1.0
**发布说明：**
```
🎉 RealityBadge 首次发布！

✨ 全新功能：
• 增强现实徽章创建
• 智能主体识别
• 3D视差效果
• 多种徽章样式
• 直观的用户界面

开始您的创意徽章之旅吧！
```

## 🔧 技术配置

### 当前配置
- **Bundle ID:** com.wujiajun.RealityBadge231
- **Team ID:** M4T239BM58 [[memory:8097932]]
- **版本号:** 1.0 (Build 1)
- **最低系统要求:** iOS 17.0+
- **支持设备:** iPhone, iPad

### 权限说明
- **相机权限:** "需要相机权限以进行实时取景与生成徽章。"
- **运动传感器权限:** "需要访问陀螺仪以实现3D视差效果。"

## ⚠️ 注意事项

1. **首次提交审核** - 通常需要1-7天审核时间
2. **测试账号** - 如果应用有登录功能，需要提供测试账号
3. **审核指南遵循** - 确保符合App Store审核指南
4. **隐私政策** - 如需要，准备隐私政策链接

## 🎯 发布后监控

- 监控应用性能和崩溃报告
- 关注用户评价和反馈
- 准备后续版本更新计划

---

**联系信息:**
- 开发者: wujiajun
- 技术支持: [您的支持邮箱]

🚀 **祝您应用发布成功！**
