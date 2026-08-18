#!/bin/bash
# 把 App 装到自己的 iPhone 上做日常试用（免费 Apple ID 签名）。
#
# 为什么要临时换 Bundle ID：
#   免费签名会把 Bundle ID **永久绑定到你的个人团队**，以后公司的付费开发者账号
#   就没法再用同一个 ID 了，只能写邮件请 Apple 支持释放。所以这里用
#   com.xinyuan.xinyuan.dev 装机，把正式的 com.xinyuan.xinyuan 留干净。
#   装完立刻改回来，仓库里不会留下 .dev 这个值。
#
# 前置（只需做一次）：
#   1. 手机用数据线连电脑，解锁，弹窗选「信任此电脑」
#   2. Xcode → Settings → Accounts → 加自己的 Apple ID（免费的就行）
#   3. 打开 frontend/ios/Runner.xcworkspace，选中 Runner target →
#      Signing & Capabilities → Team 选「你的名字 (Personal Team)」
#
# 用法：bash scripts/install_ios_test.sh
set -e
cd "$(dirname "$0")/../frontend"
PBX=ios/Runner.xcodeproj/project.pbxproj
REAL=com.xinyuan.xinyuan
DEV=com.xinyuan.xinyuan.dev

DEVICE=$(flutter devices --machine 2>/dev/null \
  | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: d=[]
for x in d:
    if x.get('targetPlatform','').startswith('ios') and not x.get('emulator'):
        print(x['id']); break")

if [ -z "$DEVICE" ]; then
  echo "❌ 没找到已连接的 iPhone。用数据线连上、解锁、并在手机上选「信任此电脑」后重试。"
  exit 1
fi
echo "→ 目标设备：$DEVICE"

# 装完一定要改回来，中途失败也要改（trap 兜底）
restore() { sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = $DEV;/PRODUCT_BUNDLE_IDENTIFIER = $REAL;/g" "$PBX"; }
trap restore EXIT

sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = $REAL;/PRODUCT_BUNDLE_IDENTIFIER = $DEV;/g" "$PBX"
echo "→ Bundle ID 临时改为 $DEV（脚本结束会自动改回）"

flutter run --release -d "$DEVICE"
