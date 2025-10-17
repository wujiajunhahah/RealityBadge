#!/bin/bash

# RealityBadge iPad 部署脚本
# 使用方法: ./deploy_to_ipad.sh [iPad名称]

set -e

echo "🚀 RealityBadge iPad 部署工具"
echo "================================"

# 检查参数
IPAD_NAME=${1:-"iPad"}
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="RealityBadge.xcodeproj"

# 检查项目目录
if [ ! -f "$PROJECT_DIR/$PROJECT_NAME" ]; then
    echo "❌ 错误: 找不到项目文件 $PROJECT_NAME"
    echo "请确保在项目根目录运行此脚本"
    exit 1
fi

echo "📱 目标设备: $IPAD_NAME"
echo "📁 项目目录: $PROJECT_DIR"

# 检查Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ 错误: 未找到Xcode"
    echo "请安装Xcode并确保命令行工具可用"
    exit 1
fi

# 检查连接的设备
echo "🔍 检查连接的设备..."
xcrun devicectl list devices

# 查找目标设备
echo "📲 查找iPad设备..."
IPAD_ID=$(xcrun devicectl list devices | grep -i "$IPAD_NAME" | head -1 | grep -oE '[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}' || echo "")

if [ -z "$IPAD_ID" ]; then
    echo "❌ 错误: 未找到iPad设备 '$IPAD_NAME'"
    echo "请确保:"
    echo "1. iPad已连接到Mac"
    echo "2. iPad已信任此电脑"
    echo "3. iPad名称正确"
    echo ""
    echo "可用设备列表:"
    xcrun devicectl list devices
    exit 1
fi

echo "✅ 找到设备: $IPAD_ID"

# 清理构建目录
echo "🧹 清理构建目录..."
cd "$PROJECT_DIR"
xcodebuild clean -project "$PROJECT_NAME" -scheme RealityBadge

# 构建项目
echo "🔨 构建项目..."
xcodebuild build \
    -project "$PROJECT_NAME" \
    -scheme RealityBadge \
    -configuration Debug \
    -destination "id=$IPAD_ID" \
    -allowProvisioningUpdates

# 安装到设备
echo "📲 安装到iPad..."
xcodebuild install \
    -project "$PROJECT_NAME" \
    -scheme RealityBadge \
    -configuration Debug \
    -destination "id=$IPAD_ID" \
    -allowProvisioningUpdates

# 启动应用
echo "🎯 启动应用..."
xcrun devicectl device process launch --device "$IPAD_ID" com.wujiajun.RealityBadge

echo ""
echo "🎉 部署成功!"
echo "✨ RealityBadge 已安装到 $IPAD_NAME"
echo ""
echo "📋 测试清单:"
echo "□ 检查应用图标是否正常显示"
echo "□ 测试应用启动速度"
echo "□ 验证相机权限请求"
echo "□ 测试量子扫描界面"
echo "□ 验证3D徽章展示"
echo "□ 测试横竖屏切换"
echo "□ 检查触觉反馈效果"
echo ""
echo "🐛 如有问题，请查看Xcode控制台输出"

# 可选: 打开控制台监控
read -p "是否打开设备控制台监控? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "📺 打开控制台监控..."
    open "xcrun simctl spawn booted log stream --predicate 'process == \"RealityBadge\"'" 2>/dev/null || \
    echo "控制台监控需要模拟器环境"
fi