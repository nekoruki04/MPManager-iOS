# Changelog

## [1.0.0] - 2026-11-17

### Initial iOS Jailbreak Port Release
- Native dual-pane file management interface modeled directly on MP Manager and MT Manager.
- Side-by-side independent navigation panes with active pane accent border highlight.
- Authentic top bar, bottom bar, and swipable bottom drawer with Bookmarks and Navigation History.
- POSIX-level rootless filesystem access supporting Dopamine 2, Dopamine 3, and RootHide.
- Embedded setuid root helper (`mpRootHelper` 4755) with automatic privilege escalation.
- Archive engine: listing entries without extraction, selective extraction, and archive creation (ZIP, 7Z, TAR.GZ, TAR.BZ2, TAR.XZ, RAR) with Zip Slip traversal protection.
- APK structure inspector, AndroidManifest.xml binary decoder, DEX class/method count parser, signature scheme checks (V1, V2, V3).
- Mach-O and ELF native binary inspector (`LC_BUILD_VERSION`, load commands, segments, linked dylibs).
- Built-in text editor with line numbers, monospaced font, regex Find & Replace, and `.bak` backups.
- Dual-column hex editor with ASCII preview and offset jumping.
- SQLite database browser with schema viewer, table picker, and SQL query execution.
- Side-by-side / unified text comparison engine (Myers diff).
- Embedded Model Context Protocol (MCP) server listening on port 8787 for AI agent interaction.
- Network storage client (FTP, FTPS, SFTP, WebDAV) with hardware-encrypted iOS Keychain storage.
- Packaged as a standard rootless Debian package (`mpmanager-rootless_1.0.0_iphoneos-arm.deb`).
