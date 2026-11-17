# MP Manager for iOS (Dopamine Rootless)

A free, native dual-pane file manager, APK/binary reverse engineering suite, and MCP server for iOS designed specifically for jailbroken devices running **Dopamine 2**, **Dopamine 3**, and **RootHide**.

Direct native port of the open-source [MP Manager](https://github.com/AbdurazaaqMohammed/MP-Manager) by Abdurazaaq Mohammed, faithfully replicating MT Manager's dual-pane paradigm on iOS with full rootless jailbreak privileges.

---

## Features

- **Authentic Dual-Pane Navigation**: Browse two directories side by side in independent viewports, highlighted with an active pane accent border (`#2196F3` / `#4CAF50`). Easily copy or move files across panes with one tap.
- **Rootless & Sandboxed Filesystem Access**: Direct access to `/var/jb`, `/var/mobile`, `/Library`, `/Applications`, and system volumes using POSIX system calls (`opendir`, `readdir`, `lstat`).
- **Privilege Elevation (`mpRootHelper`)**: Bundled setuid root helper (`chmod 4755`, owned by `0:0`) enabling uninhibited recursive deletions, permissions modifications (`chmod`/`chown`), and archive extraction in protected system folders.
- **Archive Engine**: Browse archive contents without extraction, extract selected entries, or create archives (`.zip`, `.tar.gz`, `.tar.bz2`, `.tar.xz`, `.7z`, `.rar`) with Zip Slip path traversal defense.
- **APK & Binary Tools**:
  - Decode binary `AndroidManifest.xml` (extract package, version, SDK constraints).
  - Inspect `classes.dex` headers and class counts.
  - Verify APK signature schemes (V1, V2, V3).
  - Inspect native `Mach-O` and `ELF` binaries (`LC_BUILD_VERSION`, segments, linked dylibs).
- **Built-in Editors & Viewers**:
  - **Text Editor**: Monospaced editor with line numbers, regex Find & Replace, and `.bak` backups.
  - **Hex Editor**: Dual-column hex view with ASCII pane and offset jumping.
  - **SQLite Browser**: View table schemas, inspect rows, and run custom queries.
  - **File Comparison (Diff)**: Side-by-side / unified text diff viewer.
  - **Checksum Calculator**: Real-time SHA-256, SHA-1, and MD5 computation.
- **Model Context Protocol (MCP) Server**: Embedded local HTTP/SSE daemon at `http://127.0.0.1:8787/mcp` exposing `mp_file_*`, `mp_zip_*`, and `mp_apk_*` tools for local or networked AI agents.
- **Network Storage**: Connect to `FTP`, `FTPS`, `SFTP`, and `WebDAV` servers with credentials secured in the hardware-backed iOS Keychain.

---

## Compatibility

| Environment | Architecture | Supported iOS Versions | Status |
|---|---|---|---|
| **iPad Pro 11-inch (2018, A12X)** | `arm64e` | iPadOS 16.0 – 16.5.1 | Primary Target |
| **iPhone 11 Pro (A13)** | `arm64e` | iOS 16.0 – 16.5.1 | Secondary Target |
| **Dopamine 2** | `arm64`, `arm64e` | iOS 15.0 – 16.6.1 | Verified |
| **Dopamine 3** | `arm64`, `arm64e` | iOS 15.0 – 18.7.1, 26.0 – 26.0.1 | Verified |
| **RootHide** | `arm64e` | iOS 15.0 – 16.5.1 | Verified |

---

## Installation

### Via Sileo or Zebra
1. Download `mpmanager-rootless_1.0.0_iphoneos-arm.deb` from the [Releases](https://github.com/nekoruki04/MPManager-iOS/releases) page.
2. Open with **Sileo** or **Zebra**.
3. Tap **Get** / **Install** and confirm.
4. `uicache -p /var/jb/Applications/MPManager.app` will register the application on the SpringBoard home screen.

### Via Terminal (dpkg)
```bash
dpkg -i mpmanager-rootless_1.0.0_iphoneos-arm.deb
uicache -p /var/jb/Applications/MPManager.app
```

---

## Authors & License
- Upstream Author: **Abdurazaaq Mohammed** ([@AbdurazaaqMohammed](https://github.com/AbdurazaaqMohammed))
- iOS Port Maintainer: **nekoruki** ([@nekoruki04](https://github.com/nekoruki04))
- Licensed under the **GNU General Public License v3.0 (GPLv3)**.
