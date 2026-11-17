# MP Manager Feature Migration & Capability Matrix

| Upstream Feature | Original Implementation | iOS Jailbreak Target Strategy | Status |
|---|---|---|---|
| **Dual-Pane Navigation** | Android `RelativeLayout` + 2 `RecyclerViews` | Native UIKit dual-container view with independent navigation controllers | Planned |
| **Active Pane Highlight** | `PaneHighlightView.java` (border canvas) | `UIView` border layer with animation (`#2196F3` / `#4CAF50`) | Planned |
| **Top & Bottom Bar** | XML layouts `topBar` & `bottomBar` | Custom UIKit view components matching exact button layouts and icons | Planned |
| **Sidebar Drawer** | `MyDrawerLayout` + `SidebarAdapter` | Slide-in drawer with storage capacity meters and quick links | Planned |
| **Bookmarks & History** | `bookmarks_drawer` BottomSheet | `UISheetPresentationController` / Custom bottom drawer with tabs | Planned |
| **File Operations Queue** | `FileOperationsHelper.java` background tasks | Swift Concurrency Actor (`FileOperationsQueue`) with 64 KB streaming | Planned |
| **Conflict Resolution** | `CopyConflictDialog.java` | Native modal dialog (.replace, .skip, .keepBoth auto-numbering) | Planned |
| **Rootless FS Access** | Root & Shizuku shell | POSIX system calls (`opendir`, `lstat`) + Dopamine rootless `/var/jb` | Planned |
| **Privilege Elevation** | `su` / `shizuku` | `mpRootHelper` setuid binary (4755) + `setuid(0)` at startup | Planned |
| **Archive Browsing & Extract** | `commons-compress`, `junrar`, `bin-zip` | Native `ArchiveManager` (ZIP, TAR, GZ, BZ2, XZ, 7Z, RAR via libarchive/posix) | Planned |
| **APK / Binary Inspection** | AXML, DEX, ARSC parser | Structure inspection, AndroidManifest decoder, DEX headers, ELF & Mach-O | Planned |
| **Text Editor** | Sora Editor | TextKit / `UITextView` monospaced editor with regex find & replace | Planned |
| **Hex Editor** | Custom HexView | Native dual-column hex editor (Offset, Hex Bytes, ASCII) | Planned |
| **SQLite Browser** | Android SQLiteDatabase | `libsqlite3` wrapper with schema viewer, table picker, and row inspector | Planned |
| **File Comparison (Diff)** | `java-diff-utils` | Side-by-side / unified text and file diff engine | Planned |
| **Network Storage** | `commons-net`, `smbj`, WebDAV | Real FTP, FTPS, SFTP, WebDAV clients with iOS Keychain security | Planned |
| **MCP Server** | NanoHTTPD / Streamable HTTP & SSE | Native Swift lightweight HTTP/SSE server at port 8787 | Planned |
| **Checksum Calculator** | MD5, SHA-1, SHA-256 in Java | Native CryptoKit & CommonCrypto SHA-256 / SHA-1 / MD5 calculator | Planned |
| **Shell Command Helper** | Termux intent / root shell | Interactive POSIX shell runner with stdout/stderr capture and exit code | Planned |
| **Dopamine Compatibility** | Android 7.0 - 15 | Dopamine 2 (iOS 15.0 - 16.6.1), Dopamine 3 (up to 26.0.1), RootHide | Planned |
