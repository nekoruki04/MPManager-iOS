# Changelog

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
