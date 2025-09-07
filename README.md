# Reality Badge - 现实勋章

![iOS](https://img.shields.io/badge/iOS-15.0%2B-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![Xcode](https://img.shields.io/badge/Xcode-15.0%2B-blue.svg)

一个创新的AR摄影应用，通过AI识别现实世界中的物体并生成独特的3D徽章。专为WWDC 2026设计，展示了iOS平台的最新技术能力。

## ✨ 核心特性

### 🎯 智能识别
- **VLM集成**：使用Vision框架进行实时物体识别
- **主体分割**：自动提取照片中的主体
- **手势检测**：识别手物交互，增强真实感

### 🎨 非凡体验
- **3D视差效果**：通过陀螺仪实现真实的深度感知
- **液态玻璃材质**：模拟iOS 26的先进视觉效果
- **高级触觉反馈**：精心设计的CoreHaptics体验

### 📱 完美适配
- 支持iPhone和iPad
- 深色模式优化
- 动态性能调整
- iOS 15+向后兼容

## 🚀 快速开始

### 系统要求
- iOS 15.0+
- Xcode 15.0+
- Swift 5.9+

### 安装步骤

1. 克隆仓库
```bash
git clone https://github.com/yourusername/RealityBadge.git
cd RealityBadge
```

2. 打开项目
```bash
open RealityBadge.xcodeproj
```

3. 配置签名
   - 选择你的开发团队
   - 修改Bundle Identifier为你自己的

4. 运行项目
   - 选择目标设备（推荐真机）
   - Command + R 运行

## 📸 使用指南

### 基本流程
1. **选择模式**：寻找新词、今日挑战、当前热点或我的收藏
2. **拍摄识别**：将相机对准物体，等待AI识别
3. **生成徽章**：识别成功后自动生成3D徽章
4. **互动体验**：摇动设备查看3D效果，拖动旋转视角

### 验证模式
- **严格模式**：需要手物互动才能触发
- **标准模式**：识别到物体即可（默认）
- **宽松模式**：仅基于语义匹配

## 🏗️ 项目结构

```
RealityBadge/
├── RealityBadgeApp.swift      # 应用入口
├── Models.swift               # 数据模型
├── Views/
│   ├── HomeView.swift         # 主界面
│   ├── CaptureView.swift      # 相机界面
│   ├── Badge3DView.swift      # 3D徽章展示
│   └── BadgeWallView.swift    # 徽章墙
├── Core/
│   ├── SemanticEngine.swift   # AI识别引擎
│   ├── HapticEngine.swift     # 触觉反馈系统
│   └── LiquidGlassEffect.swift # 液态玻璃效果
├── UI/
│   ├── Animations.swift       # 动画系统
│   └── ButtonStyles.swift     # 自定义按钮样式
└── Resources/
    └── Info.plist            # 应用配置
```

## 🎨 设计理念

### 视觉设计
- **层次分明**：使用毛玻璃材质创建深度
- **动态响应**：每个交互都有视觉反馈
- **优雅过渡**：流畅的动画连接各个状态

### 交互设计
- **直觉操作**：符合iOS用户习惯
- **触觉增强**：精细的震动反馈
- **手势丰富**：拖动、摇晃、长按等

### 性能优化
- **智能降级**：根据设备性能调整效果
- **异步处理**：不阻塞主线程
- **内存管理**：及时释放大图像资源

## 🛠️ 技术栈

- **SwiftUI** - 现代化的UI框架
- **Vision** - 图像识别和分析
- **CoreMotion** - 陀螺仪数据
- **CoreHaptics** - 高级触觉反馈
- **AVFoundation** - 相机捕获

## 📝 开发计划

- [ ] 集成真实的VLM API
- [ ] 添加云同步功能
- [ ] 支持AR模式展示
- [ ] 社交分享功能
- [ ] 徽章交易市场

## 🤝 贡献指南

欢迎提交Issue和Pull Request！请确保：
- 遵循现有代码风格
- 添加必要的注释
- 测试在不同设备上的表现

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 🙏 致谢

- 感谢Apple提供的强大开发工具
- 设计灵感来自iOS的设计语言
- 特别为WWDC 2026准备

---

Made with ❤️ for WWDC 2026