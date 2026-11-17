#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
APP_DIR="$BUILD_DIR/MPManager.app"
ENTITLEMENTS="$PROJECT_ROOT/Packaging/MPManager.entitlements"

echo "[*] Project root: $PROJECT_ROOT"
echo "[*] App bundle: $APP_DIR"

mkdir -p "$APP_DIR"

SWIFT_SOURCES=(
    "$PROJECT_ROOT/App/AppDelegate.swift"
    "$PROJECT_ROOT/App/SceneDelegate.swift"
    "$PROJECT_ROOT/Core/Theme/MPTheme.swift"
    "$PROJECT_ROOT/Core/FileSystem/FileItem.swift"
    "$PROJECT_ROOT/Core/FileSystem/RootlessPaths.swift"
    "$PROJECT_ROOT/Core/FileSystem/FileSystemProvider.swift"
    "$PROJECT_ROOT/Core/Privilege/PrivilegeManager.swift"
    "$PROJECT_ROOT/Core/FileOperations/FileOperation.swift"
    "$PROJECT_ROOT/Core/FileOperations/ConflictResolver.swift"
    "$PROJECT_ROOT/Core/FileOperations/FileOperationsQueue.swift"
    "$PROJECT_ROOT/Core/Security/CryptEngine.swift"
    "$PROJECT_ROOT/Core/Storage/BookmarkStore.swift"
    "$PROJECT_ROOT/Core/Network/KeychainHelper.swift"
    "$PROJECT_ROOT/Core/Network/NetworkStorageItem.swift"
    "$PROJECT_ROOT/Core/Network/NetworkStorageClient.swift"
    "$PROJECT_ROOT/Jailbreak/JailbreakEnvironment.swift"
    "$PROJECT_ROOT/Features/Archive/ArchiveManager.swift"
    "$PROJECT_ROOT/Features/Search/FileSearchEngine.swift"
    "$PROJECT_ROOT/Features/ApkTools/ApkInspector.swift"
    "$PROJECT_ROOT/Features/ApkTools/ApkInfoViewController.swift"
    "$PROJECT_ROOT/Features/BinaryTools/MachOInspector.swift"
    "$PROJECT_ROOT/Features/Editors/TextEditorViewController.swift"
    "$PROJECT_ROOT/Features/Editors/HexEditorViewController.swift"
    "$PROJECT_ROOT/Features/SQLite/SQLiteBrowserViewController.swift"
    "$PROJECT_ROOT/Features/Diff/FileDiffViewController.swift"
    "$PROJECT_ROOT/Features/MCP/McpServer.swift"
    "$PROJECT_ROOT/Features/MCP/McpServerViewController.swift"
    "$PROJECT_ROOT/Features/FileBrowser/PaneHighlightView.swift"
    "$PROJECT_ROOT/Features/FileBrowser/FileCell.swift"
    "$PROJECT_ROOT/Features/FileBrowser/FilePropertiesViewController.swift"
    "$PROJECT_ROOT/Features/FileBrowser/BookmarksDrawerViewController.swift"
    "$PROJECT_ROOT/Features/FileBrowser/SideDrawerViewController.swift"
    "$PROJECT_ROOT/Features/FileBrowser/SearchDialogViewController.swift"
    "$PROJECT_ROOT/Features/FileBrowser/MainFilesViewController.swift"
    "$PROJECT_ROOT/Features/FileBrowser/DualPaneViewController.swift"
    "$PROJECT_ROOT/Features/Network/NetworkStorageViewController.swift"
    "$PROJECT_ROOT/Features/Settings/SettingsViewController.swift"
)

SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"
echo "[*] Using iPhoneOS SDK: $SDK_PATH"

echo "[*] Compiling Swift sources for arm64 iOS 16.0..."
swiftc \
    -target arm64-apple-ios16.0 \
    -sdk "$SDK_PATH" \
    -module-name MPManager \
    -O \
    -whole-module-optimization \
    -parse-as-library \
    -emit-executable \
    -o "$APP_DIR/MPManager" \
    "${SWIFT_SOURCES[@]}"

echo "[*] Compiling mpRootHelper binary..."
xcrun --sdk iphoneos clang \
    -target arm64-apple-ios16.0 \
    -isysroot "$SDK_PATH" \
    -O2 \
    "$PROJECT_ROOT/Core/Privilege/mpRootHelper.c" \
    -o "$APP_DIR/mpRootHelper"

xcrun vtool -set-build-version ios 16.0 18.5 -replace -output "$APP_DIR/mpRootHelper" "$APP_DIR/mpRootHelper"
ldid -S"$ENTITLEMENTS" "$APP_DIR/mpRootHelper"

echo "[*] Copying bundle resources..."
cp "$PROJECT_ROOT/App/Info.plist" "$APP_DIR/Info.plist"
if [ -f "$PROJECT_ROOT/Packaging/icon.png" ]; then
    cp "$PROJECT_ROOT/Packaging/icon.png" "$APP_DIR/icon.png"
    cp "$PROJECT_ROOT/Packaging/icon.png" "$APP_DIR/AppIcon60x60@2x.png"
    cp "$PROJECT_ROOT/Packaging/icon.png" "$APP_DIR/AppIcon76x76@2x~ipad.png"
fi

echo "[*] Retargeting Mach-O platform version to iOS 16.0..."
xcrun vtool -set-build-version ios 16.0 18.5 -replace -output "$APP_DIR/MPManager" "$APP_DIR/MPManager"

echo "[*] Signing executable with entitlements..."
ldid -S"$ENTITLEMENTS" "$APP_DIR/MPManager"

echo "[+] MPManager.app compiled and signed successfully."
file "$APP_DIR/MPManager"
