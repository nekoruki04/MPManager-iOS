# Changelog

## [1.1.3] - 2026-11-17

### Fixed
- **App Containers & Installed Apps Crash Resolution**:
  - Eliminated unsafe Objective-C runtime private selector reflection (`_applicationIconImageForBundleIdentifier:format:scale:`) that triggered `EXC_BAD_ACCESS` / `SIGSEGV` or uncaught exceptions on system daemons and view services lacking standard assets.
  - Implemented safe native icon resolution using `.app` bundle directory scanning and `Bundle(path:)` asset lookups with zero crash risk.
  - Corrected display names for system daemons: falls back to clean bundle folder name instead of empty string ` (1.0)`.
  - Added dedicated SF Symbol fallbacks with distinct theme tints (`terminal` for Jailbreak, `applelogo` for System, `app.gift` for User apps) when no image asset is bundled.
- **Universal iPadOS ActionSheet Crash Prevention (`present_adaptive_sheet`)**:
  - Automatically configures popover presentation anchoring across all `UIAlertController(preferredStyle: .actionSheet)` views to prevent `NSGenericException` crashes on iPad Pro and iPadOS devices.

## [1.1.2] - 2026-11-17

### Fixed
- **Native ZIP Archiving & Extraction Engine (`NativeZipEngine`)**:
  - Replaced CLI-dependent zip/unzip subprocess invocation with a self-contained, native streaming PKZIP engine using Darwin kernel `zlib`.
  - Fixes zip archive creation errors when `zip` binary is not installed in `/var/jb/usr/bin`.
  - Fixed fallback to `tar` which caused format mismatch and corruption on `.zip` destinations.
  - Streaming file writing via `FileHandle` with RFC 1951 Deflate compression, correct DOS date/time encoding, and Central Directory generation.
  - Native ZIP listing and extraction with Deflate inflation and path traversal protection.

## [1.1.1] - 2026-11-17

### Fixed
- **App Containers & Installed Apps Icon Resolution**:
  - Implemented multi-tier real app icon resolution in `AppManagerViewController`:
    1. Extracts `CFBundleIcons` and `CFBundlePrimaryIcon` candidate files (`@3x.png`, `@2x.png`, `~ipad.png`, `.png`) directly from the `.app` bundle.
    2. Deep bundle directory scanning for icon assets.
    3. Dynamic Objective-C runtime fallback via `UIImage._applicationIconImageForBundleIdentifier:format:scale:` for compiled and system application icons.
  - Added in-memory `NSCache` for fluid table scrolling.
  - Standardized all application icons to crisp 38x38 squircle rendering (`cornerRadius: 8`).

## [1.1.0] - 2026-11-17

### Added
- **Media Suite**:
  - Built-in Audio & Video player (`AudioVideoPlayerViewController`) with `AVPlayer`, seek slider, play/pause, 10-second skip forward/backward, time labels, and background audio support.
  - Image viewer & editor (`ImageViewerViewController`) with directory swipe navigation, pinch-to-zoom, EXIF metadata inspector, 90-degree rotate, flip, and private EXIF data stripping (**Strip EXIF**).
  - Built-in PDF reader (`PdfViewerViewController`) powered by `PDFKit` with continuous scroll, page indicator, in-document text search, and share sheet.
- **Application & Container Management**:
  - Installed Apps & Containers viewer (`AppManagerViewController`) categorizing User, System, and Jailbreak applications.
  - Direct mapping from Bundle IDs to App Sandbox Data Containers (`/var/mobile/Containers/Data/Application/<UUID>`) via `.com.apple.mobile_container_manager.metadata.plist` decoding.
  - Quick action to jump straight into an app's Bundle folder or Data Sandbox container.
- **Utilities & Tool Packs**:
  - **Batch Rename (`BatchRenameViewController`)**: Rename multiple files with template rules (prefix, suffix, `#` index padding) or Find & Replace, with live preview before applying.
  - **Shell Command Runner (`ShellRunnerViewController`)**: Interactive terminal output viewer with real-time stdout/stderr capture via `posix_spawnp`, exit code badge, and setuid root switch.
  - **Command Helper (`CommandHelperViewController`)**: Pre-configured developer templates (`chmod 755`, `ldid -S`, `dpkg-deb`, `otool -L`) and customizable template expansions (`$FILE`, `$DIR`, `$NAME`).
  - **Storage Manager (`StorageManagerViewController`)**: Disk capacity breakdown via `statvfs` (Total, Used, Free) and Top 50 largest files scanner with direct deletion and navigation.
  - **Wi-Fi & Network Manager (`WifiManagerViewController`)**: Low-level network interface metrics via BSD `getifaddrs` (interface name, IPv4, cellular IP, netmask, broadcast address).
  - **Backup Restore**: Automatic restoration dialog when tapping `.bak` backup files.
- **Documentation & Evidence**:
  - Added real-device preview screenshots to repository documentation.

## [1.0.0] - 2026-11-17

### Initial iOS Jailbreak Port Release
- Native dual-pane file management interface modeled directly on MP Manager and MT Manager.
- Side-by-side independent navigation panes with active pane accent border highlight.
- Authentic top bar, bottom bar, and swipable bottom drawer with Bookmarks and Navigation History.
- POSIX-level rootless filesystem access supporting Dopamine 2, Dopamine 3, and RootHide.
- Embedded setuid root helper (`mpRootHelper` 4755) with automatic privilege escalation.
- **Complete Model Context Protocol (MCP) Server**:
  - Full JSON-RPC 2.0 protocol layer compliant with MCP specification `2024-11-05`.
  - 23 on-device tools (`mp_file_*`, `mp_zip_*`, `mp_apk_*`, `mp_macho_*`, `mp_exec_command`, `mp_network_list`, `mp_ftp_server_status`).
  - Dual transports: Streamable HTTP at `http://<ip>:8787/mcp` and Legacy SSE at `/sse` & `/message`.
  - Live console audit logging and one-click JSON export for Claude Desktop and Cursor.
  - Background task execution keepalive.
- **Comprehensive Network Storage & Wireless File Transfer**:
  - Built-in RFC 959 FTP Server over BSD sockets & GCD on port 2121 with anonymous / user authentication, passive mode (PASV/EPSV), file upload/download, and background keepalive.
  - Native Swift WebDAV client using `URLSession` and `XMLParser` with `PROPFIND` (Depth 1), `GET`, `PUT`, `MKCOL`, `DELETE`, and `MOVE`.
  - Dedicated Remote Files Browser (`RemoteFilesViewController`) with directory traversal, upload, download, and text editing.
  - FTP Server UI with local WiFi IP discovery (`ftp://192.168.x.x:2121`), share sheet, copy URL, and active transfer logs.
  - Keychain-backed credential storage for FTP, FTPS, SFTP, WebDAV, and SMB.
- Archive engine: listing entries without extraction, selective extraction, and archive creation (ZIP, 7Z, TAR.GZ, TAR.BZ2, TAR.XZ, RAR) with Zip Slip traversal protection.
- APK structure inspector, AndroidManifest.xml binary decoder, DEX class/method count parser, signature scheme checks (V1, V2, V3).
- Mach-O and ELF native binary inspector (`LC_BUILD_VERSION`, load commands, segments, linked dylibs).
- Built-in text editor with line numbers, monospaced font, regex Find & Replace, and `.bak` backups.
- Dual-column hex editor with ASCII preview and offset jumping.
- SQLite database browser with schema viewer, table picker, and SQL query execution.
- Side-by-side / unified text comparison engine (Myers diff).
- Packaged as a standard rootless Debian package (`mpmanager-rootless_1.0.0_iphoneos-arm.deb`).
