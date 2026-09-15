#!/bin/bash
# 版本号统一升级脚本 —— VERSION 是唯一真源，其余位置由本脚本派生写入。
#
#   ./scripts/bump-version.sh 2.5.3
#
# 写入的位置：
#   VERSION                              真源
#   windows/src-tauri/Cargo.toml         Windows 端 App 上报版本（CARGO_PKG_VERSION）与 Tauri 打包版本
#   windows/package.json                 npm 元数据
#   windows/package-lock.json            交给 npm 自动同步（不手改嵌套字段）
#
# macOS 端不写死版本：build.sh 与 CI 都读 VERSION；CI 的 tag 构建以 tag 为准，
# 并校验 tag、VERSION、Cargo.toml、package.json 四者一致（见 release-*.yml）。
set -e

cd "$(dirname "$0")/.."

NEW_VERSION="${1#v}"

if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "用法：./scripts/bump-version.sh <x.y.z>（例：./scripts/bump-version.sh 2.5.3）" >&2
    exit 1
fi

CURRENT_VERSION="$(tr -d '[:space:]' < VERSION 2>/dev/null || echo '')"
if [ "$CURRENT_VERSION" != "$NEW_VERSION" ]; then
    printf '%s\n' "$NEW_VERSION" > VERSION
fi

# Cargo.toml：只替换 [package] 段内的 version 行（依赖段的 version 不动）
TMP_CARGO="$(mktemp)"
sed -E "/^\[package\]/,/^\[/ s/^version = \"[^\"]+\"/version = \"$NEW_VERSION\"/" \
    windows/src-tauri/Cargo.toml > "$TMP_CARGO"
mv "$TMP_CARGO" windows/src-tauri/Cargo.toml

# package.json：顶层 version（依赖项用的是 "^x.y.z" 形式，不会误伤）
TMP_PKG="$(mktemp)"
sed -E "s/^  \"version\": \"[^\"]+\",/  \"version\": \"$NEW_VERSION\",/" \
    windows/package.json > "$TMP_PKG"
mv "$TMP_PKG" windows/package.json

# package-lock.json：交给 npm 同步，避免手改两个嵌套字段
if command -v npm >/dev/null 2>&1; then
    (cd windows && npm install --package-lock-only --silent --no-audit --no-fund >/dev/null)
else
    echo "⚠️  未找到 npm，请手动同步 windows/package-lock.json 的两处 version" >&2
fi

echo "✅ 版本号已统一为 ${NEW_VERSION}："
echo "   VERSION                          $(tr -d '[:space:]' < VERSION)"
echo "   windows/src-tauri/Cargo.toml     $(grep -m1 '^version = ' windows/src-tauri/Cargo.toml | cut -d'"' -f2)"
echo "   windows/package.json             $(grep -m1 '\"version\"' windows/package.json | cut -d'"' -f4)"
echo "   windows/package-lock.json        $(grep -m1 '\"version\"' windows/package-lock.json | cut -d'"' -f4)"
