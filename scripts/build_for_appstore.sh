#!/usr/bin/env bash
set -euo pipefail

# RealityBadge App Store Release Build Script
# 用于生成App Store上传的Archive构建

echo "🚀 开始构建RealityBadge用于App Store发布..."

# 检查必需环境变量
if [[ -z "${TEAM_ID:-}" ]]; then
  echo "❌ 请设置TEAM_ID环境变量"
  echo "   export TEAM_ID=M4T239BM58  # 你的Apple Team ID"
  exit 1
fi

# 设置构建参数
SCHEME="RealityBadge"
CONFIG="Release"
BUNDLE_ID="com.wujiajun.RealityBadge231"
DERIVED="$(pwd)/build/AppStoreRelease"
ARCHIVE_PATH="$DERIVED/RealityBadge.xcarchive"

# 清理之前的构建
echo "🧹 清理之前的构建..."
rm -rf "$DERIVED"
mkdir -p "$DERIVED"

# 执行Archive构建
echo "📦 开始Archive构建..."
xcodebuild \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED" \
  -archivePath "$ARCHIVE_PATH" \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  CODE_SIGN_STYLE=Automatic \
  archive

if [[ ! -d "$ARCHIVE_PATH" ]]; then
  echo "❌ Archive构建失败！"
  exit 1
fi

echo "✅ Archive构建成功！"
echo "📁 Archive路径: $ARCHIVE_PATH"
echo ""
echo "📋 下一步操作："
echo "1. 打开Xcode"
echo "2. Window → Organizer"
echo "3. 选择刚才创建的Archive"
echo "4. 点击 'Distribute App'"
echo "5. 选择 'App Store Connect'"
echo "6. 按提示上传到App Store Connect"
echo ""
echo "🎉 准备上线完成！"
