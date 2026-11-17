# MP Manager Upstream Architecture & System Map

## 1. Upstream Identity & Origins
- **Repository:** https://github.com/AbdurazaaqMohammed/MP-Manager
- **Upstream License:** GPLv3
- **Primary Goal:** Open-source, dual-pane file manager for Android, designed as a free, transparent alternative to MT Manager, specialized in APK analysis, dual-pane operations, binary reverse engineering, and AI integration via MCP.

---

## 2. Seven-Layer Architecture Mapping

| Layer | Upstream Java Package | Core Functionality | Native iOS Target Architecture |
|---|---|---|---|
| **App Shell** | `io.github.abdurazaaqmohammed.app` | Application lifecycle, ServiceLocator, startup configuration | `MPManager/App/AppDelegate.swift`, `SceneDelegate.swift` |
| **UI Layer** | `io.github.abdurazaaqmohammed.ui.main`, `ui.viewer`, `ui.editor`, `ui.common` | Dual-pane layout, FastScroller list, Material dialogs, editors, viewers | UIKit custom dual-pane controller, `MainFilesViewController`, `PaneHighlightView` |
| **Feature Layer** | `io.github.abdurazaaqmohammed.feature.{files, apk, sqlite, diff, ftp, system}` | Business operations: search, conflict handling, APK tools, diff, SQLite | `MPManager/Features/{FileBrowser, Search, Archive, Editors, ApkTools, SQLite, Diff}` |
| **Plugin / Packs** | `io.github.abdurazaaqmohammed.plugins` | Tool packs and external plugin extensions | Integrated tools hub with native iOS extensions |
| **MCP Service** | `io.github.abdurazaaqmohammed.mcp` | Local HTTP/SSE server exposing `mp_file_*`, `mp_zip_*`, `mp_apk_*` tools | `MPManager/Features/MCP/McpServer.swift`, `McpToolRegistry.swift` |
| **Privilege Layer** | `io.github.abdurazaaqmohammed.privilege` | Root abstraction, Shizuku, su commands | `MPManager/Core/Privilege/PrivilegeManager.swift` + `mpRootHelper` (setuid 4755) |
| **Data & Storage** | `io.github.abdurazaaqmohammed.data.prefs` | Key-value settings, bookmarks, navigation history, Keychain | `MPManager/Core/Storage/BookmarkStore.swift`, `KeychainHelper.swift` |
| **Utility Layer** | `io.github.abdurazaaqmohammed.util.{io, archive, hash, text, net}` | Streaming IO, archive engine, PBKDF2/AES-GCM, network clients | `MPManager/Core/{FileSystem, Security, Network}`, `ArchiveManager.swift` |

---

## 3. Core UI/UX Subsystems
1. **Dual-Pane Viewport:**
   - Two side-by-side independent navigation panes (`Pane 1` and `Pane 2`).
   - Active pane dynamically highlighted with a distinct Material accent border (`#2196F3` / `#4CAF50`).
   - Independent history navigation stacks (Back / Forward).
   - Sync button (`baseline_swap_horiz_24`) aligning both panes to the same directory.
2. **Top Navigation Bar:**
   - Hamburger drawer icon (`baseline_menu_24`).
   - Current directory path with max 1 line truncation.
   - Folder item count (`folderCount`).
   - More options menu (`baseline_more_vert_24`).
3. **Bottom Action Bar:**
   - Back, Forward, New File/Folder (`+`), Sync Panes, Up (Parent).
4. **Bookmarks & History Bottom Sheet:**
   - Swipable bottom drawer with tabs for `Bookmarks` and `History`.
   - Long-press contextual operations (edit, delete, reorder).
5. **Sidebar Navigation Drawer:**
   - Storage volume overview with progress bars (Internal Storage, Root, Dopamine `/var/jb`, Media).
   - Quick navigation items: Bookmarks, Tools Hub, MCP Service, Settings.
6. **Contextual Action Menu (MT-Style Long-Press):**
   - Copy, Move, Rename, Delete, Chmod, Properties, Add to ZIP, Open with, Compare.
   - Fully customizable order.
