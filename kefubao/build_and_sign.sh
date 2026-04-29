#!/bin/bash

# ==================== 配置区域 ====================
APP_NAME="客服宝"
APP_PATH="/Users/atlantis/Desktop/${APP_NAME}.app"
VERSION_SHORT="6.0.0"        # 用户可见版本
VERSION_BUILD="20260501"      # 手动修改构建号
OUTPUT_DIR="/Users/atlantis/Desktop"

# 开发者信息
TEAM_NAME="Developer ID Application: Shenzhen Qianbaichi Network Technology Co., Ltd. (G63SUQ4JVZ)"
APPLE_ID="kefubao@hotmail.com"
TEAM_ID="G63SUQ4JVZ"
APP_SPECIFIC_PASSWORD="sjat-shnf-jwqa-bsug"

# Sparkle 路径
SPARKLE_BIN="/Users/atlantis/Desktop/HuYun仓库/客服宝-Mac/Pods/Sparkle/bin"

# 发布日期（自动生成北京时间）
PUB_DATE=$(TZ='Asia/Shanghai' date +"%a, %d %b %Y %H:%M:%S +0800")

# ==================== 更新日志（每次发布时修改这里）====================
CHANGELOG=(
    "✅ 话术分段，表情，随机文字"
    "✅ 短语功能"
    "✅ 手机号登录"
    "✅ 性能优化"
    "✅ 修复已知问题"
)

# ==================== 解析参数 ====================
FORMAT=${1:-"zip"}  # 默认 zip，可选 dmg

# 转换为小写
FORMAT=$(echo "$FORMAT" | tr '[:upper:]' '[:lower:]')

# 验证格式
if [[ "$FORMAT" != "zip" && "$FORMAT" != "dmg" ]]; then
    echo "❌ 错误：不支持的格式 '$FORMAT'"
    echo "使用方法: $0 [zip|dmg]"
    exit 1
fi

# 设置文件路径和类型
if [ "$FORMAT" == "zip" ]; then
    OUTPUT_PATH="${OUTPUT_DIR}/${APP_NAME}_${VERSION_SHORT}.zip"
    FILE_TYPE="application/zip"
    echo "📦 打包格式: ZIP"
else
    OUTPUT_PATH="${OUTPUT_DIR}/${APP_NAME}_${VERSION_SHORT}.dmg"
    FILE_TYPE="application/octet-stream"
    echo "💿 打包格式: DMG"
fi

# ==================== 颜色输出 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_info() { echo -e "${BLUE}📌 $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# 生成更新日志 HTML
generate_changelog() {
    local html=""
    for item in "${CHANGELOG[@]}"; do
        html="${html}                <li>${item}</li>\n"
    done
    echo -e "$html"
}

# ==================== 打包函数 ====================
package_zip() {
    print_info "打包成 ZIP 文件..."
    cd "$OUTPUT_DIR"
    
    # 删除旧的 ZIP 文件
    if [ -f "$OUTPUT_PATH" ]; then
        rm "$OUTPUT_PATH"
        print_info "删除旧的 ZIP 文件"
    fi
    
    # 使用 ditto 打包
    ditto -c -k --sequesterRsrc --keepParent "$APP_NAME.app" "$OUTPUT_PATH"
    
    if [ $? -eq 0 ] && [ -f "$OUTPUT_PATH" ]; then
        FILE_SIZE=$(ls -lh "$OUTPUT_PATH" | awk '{print $5}')
        print_success "ZIP 打包完成 (大小: ${FILE_SIZE})"
        return 0
    else
        print_error "ZIP 打包失败"
        return 1
    fi
}

package_dmg() {
    print_info "打包成 DMG 文件..."
    
    TEMP_DMG="/tmp/temp_dmg"
    DMG_VOLUME_NAME="${APP_NAME} ${VERSION_SHORT}"
    
    # 清理临时目录
    if [ -d "$TEMP_DMG" ]; then
        rm -rf "$TEMP_DMG"
    fi
    mkdir -p "$TEMP_DMG"
    
    # 复制应用到临时目录
    cp -R "$APP_PATH" "$TEMP_DMG/"
    
    # 创建 Applications 快捷方式
    ln -s /Applications "$TEMP_DMG/Applications"
    
    # 删除旧的 DMG 文件
    if [ -f "$OUTPUT_PATH" ]; then
        rm "$OUTPUT_PATH"
        print_info "删除旧的 DMG 文件"
    fi
    
    # 创建 DMG
    hdiutil create -volname "$DMG_VOLUME_NAME" \
      -srcfolder "$TEMP_DMG" \
      -ov -format UDZO \
      "$OUTPUT_PATH"
    
    # 清理临时目录
    rm -rf "$TEMP_DMG"
    
    if [ $? -eq 0 ] && [ -f "$OUTPUT_PATH" ]; then
        FILE_SIZE=$(ls -lh "$OUTPUT_PATH" | awk '{print $5}')
        print_success "DMG 打包完成 (大小: ${FILE_SIZE})"
        return 0
    else
        print_error "DMG 打包失败"
        return 1
    fi
}

sign_dmg() {
    print_info "签名 DMG 文件..."
    codesign --sign "$TEAM_NAME" "$OUTPUT_PATH"
    if [ $? -eq 0 ]; then
        print_success "DMG 签名完成"
        codesign --verify "$OUTPUT_PATH"
        return 0
    else
        print_error "DMG 签名失败"
        return 1
    fi
}

staple_dmg() {
    print_info "装订公证票据到 DMG..."
    xcrun stapler staple "$OUTPUT_PATH"
    if [ $? -eq 0 ]; then
        print_success "票据装订完成"
        print_info "验证装订..."
        xcrun stapler validate "$OUTPUT_PATH"
        return 0
    else
        print_warning "票据装订失败"
        return 1
    fi
}

# ==================== 开始构建 ====================
echo ""
print_info "开始构建 ${APP_NAME} v${VERSION_SHORT} (Build: ${VERSION_BUILD})"
echo "================================================"

# 1. 检查 .app 是否存在
print_info "1. 检查应用文件..."
if [ ! -d "$APP_PATH" ]; then
    print_error "找不到 ${APP_PATH}"
    exit 1
fi
print_success "应用文件存在"

# 2. 签名 .app
print_info "2. 签名应用..."
codesign --force --options runtime --timestamp --deep \
  --sign "$TEAM_NAME" "$APP_PATH"

if [ $? -eq 0 ]; then
    print_success "签名完成"
else
    print_error "签名失败"
    exit 1
fi

# 3. 验证签名
print_info "3. 验证签名..."
codesign --verify --deep --strict "$APP_PATH"
if [ $? -eq 0 ]; then
    print_success "签名验证通过"
else
    print_error "签名验证失败"
    exit 1
fi

# 显示签名详情
codesign -dvvv "$APP_PATH" 2>&1 | grep "Authority"

# 4. 打包（根据格式选择）
print_info "4. 打包文件..."
if [ "$FORMAT" == "zip" ]; then
    package_zip
else
    package_dmg
fi

if [ $? -ne 0 ]; then
    exit 1
fi

# 5. DMG 需要额外签名
if [ "$FORMAT" == "dmg" ]; then
    sign_dmg
    if [ $? -ne 0 ]; then
        exit 1
    fi
fi

# 6. 公证
print_info "5. 提交公证（这可能需要几分钟）..."
xcrun notarytool submit "$OUTPUT_PATH" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" \
  --password "$APP_SPECIFIC_PASSWORD" \
  --wait --timeout 600

if [ $? -eq 0 ]; then
    print_success "公证提交成功"
else
    print_error "公证失败"
    exit 1
fi

# 7. DMG 需要装订票据，ZIP 不需要
if [ "$FORMAT" == "dmg" ]; then
    staple_dmg
else
    print_info "6. ZIP 格式处理..."
    print_warning "ZIP 格式不需要 stapler 装订，跳过此步骤"
    print_success "公证已完成，ZIP 可直接用于 Sparkle 更新"
    
    # 可选：显示公证历史
    print_info "公证信息验证..."
    xcrun notarytool history --apple-id "$APPLE_ID" \
      --team-id "$TEAM_ID" \
      --password "$APP_SPECIFIC_PASSWORD" | head -5
fi

# 8. 生成 Sparkle 签名
print_info "生成 Sparkle 更新签名..."
cd "$SPARKLE_BIN"

if [ ! -f "./sign_update" ]; then
    print_error "找不到 sign_update 工具，请检查 Sparkle 路径"
    exit 1
fi

SIGN_OUTPUT=$(./sign_update "$OUTPUT_PATH")
echo "$SIGN_OUTPUT"

# 9. 输出 appcast 条目
echo ""
print_info "9. 以下是需要添加到 appcast.xml 的内容："
echo "================================================"
echo ""

# 提取签名和长度
ED_SIGNATURE=$(echo "$SIGN_OUTPUT" | grep -o 'sparkle:edSignature="[^"]*"' | head -1 | cut -d'"' -f2)
LENGTH=$(echo "$SIGN_OUTPUT" | grep -o 'length="[^"]*"' | head -1 | cut -d'"' -f2)

if [ -n "$ED_SIGNATURE" ] && [ -n "$LENGTH" ]; then
    # 生成更新日志
    CHANGELOG_HTML=$(generate_changelog)
    
    # 根据格式设置下载 URL
    if [ "$FORMAT" == "zip" ]; then
        #DOWNLOAD_URL="https://raw.githubusercontent.com/HuYun28/macOS/main/kefubao/客服宝_${VERSION_SHORT}.zip"
        DOWNLOAD_URL="https://ghproxy.net/https://raw.githubusercontent.com/HuYun28/macOS/main/kefubao/%E5%AE%A2%E6%9C%8D%E5%AE%9D_${VERSION_SHORT}.zip"
    else
        #DOWNLOAD_URL="https://raw.githubusercontent.com/HuYun28/macOS/main/kefubao/客服宝_${VERSION_SHORT}.dmg"
        DOWNLOAD_URL="https://ghproxy.net/https://raw.githubusercontent.com/HuYun28/macOS/main/kefubao/%E5%AE%A2%E6%9C%8D%E5%AE%9D_${VERSION_SHORT}.dmg"
    fi
    
    cat << EOF
        <item>
            <title>版本 ${VERSION_SHORT}</title>
            <pubDate>${PUB_DATE}</pubDate>
            <sparkle:version>${VERSION_BUILD}</sparkle:version>
            <sparkle:shortVersionString>${VERSION_SHORT}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>10.15</sparkle:minimumSystemVersion>
            
            <!-- 添加这一行，启用自动更新 -->
            <!-- <sparkle:automaticUpdate>true</sparkle:automaticUpdate> -->
            
            <description><![CDATA[
                <h2>${APP_NAME} ${VERSION_SHORT}</h2>
                <ul>
${CHANGELOG_HTML}
                </ul>
            ]]></description>
            
            <enclosure url="${DOWNLOAD_URL}"
            sparkle:version="${VERSION_BUILD}"
            sparkle:shortVersionString="${VERSION_SHORT}"
            sparkle:edSignature="${ED_SIGNATURE}"
            length="${LENGTH}"
            type="${FILE_TYPE}" />
        </item>
EOF
else
    print_warning "无法自动提取签名信息，请手动复制上面的签名输出"
fi

echo ""
echo "================================================"
print_success "所有步骤完成！"
echo ""
print_info "生成的文件位置: ${OUTPUT_PATH}"
print_info "打包格式: ${FORMAT^^}"
print_info "版本号: ${VERSION_SHORT}"
print_info "构建号: ${VERSION_BUILD}"
print_info "发布日期: ${PUB_DATE}"
echo ""
print_info "更新日志："
for item in "${CHANGELOG[@]}"; do
    echo "  - $item"
done
echo ""
print_warning "请将上面的 XML 内容添加到你的 appcast.xml 文件中"