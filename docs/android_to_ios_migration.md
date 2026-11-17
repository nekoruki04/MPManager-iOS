# Android to iOS Migration Guide for MP Manager

## 1. Runtime & API Transformation

| Android Concept | Upstream Implementation | iOS Dopamine Rootless Native Replacement |
|---|---|---|
| **Process Model** | Android Linux zygote / app sandbox | Mach-O executable, SpringBoard launched, `com.apple.private.security.no-sandbox` |
| **Storage Access** | SAF (`DocumentsProvider`, `Uri`) | POSIX filesystem (`/var/mobile`, `/var/jb`, `/Library`, `/Applications`) |
| **Root Execution** | `su` / `shizuku` process IPC | Setuid root helper binary (`mpRootHelper` 4755) + `setuid(0)` syscall |
| **Archive Browsing** | Java `commons-compress` | Native `ArchiveManager` with POSIX `tar`, `bsdtar`, `unzip`, `7z` |
| **AXML & APK Manifest** | Java AXML decoder | Native binary XML & AXML string pool decoder |
| **DEX Analysis** | `dex2jar` / `jadx-core` | Native DEX header & class/method string table parser |
| **Native Binary Tools** | `libmp_zstd.so` / ELF parser | Native Mach-O (`LC_BUILD_VERSION`, load commands, symbols) & ELF parser |
| **Text Editing** | Sora Editor (Android View) | TextKit / `UITextView` with line numbering and regex search/replace |
| **Network Storage** | `commons-net`, `smbj` | `NetworkStorageClient` (FTP, FTPS, SFTP, WebDAV) + iOS Keychain |
| **Local MCP Service** | NanoHTTPD on port 8787 | Native Swift POSIX socket / HTTP server at `127.0.0.1:8787` |
| **Key Storage** | Android Keystore | iOS Security Framework Keychain (`kSecClassGenericPassword`) |

---

## 2. Dopamine Rootless Privilege Architecture
On iOS with Dopamine Rootless:
1. Application installed into `/var/jb/Applications/MPManager.app`.
2. Main executable signed with `platform-application` and `com.apple.private.security.no-sandbox`.
3. Standalone root helper binary `mpRootHelper` bundled at `/var/jb/Applications/MPManager.app/mpRootHelper` with mode `4755` (`root:wheel`).
4. On launch, `AppDelegate` invokes `setuid(0); setgid(0); seteuid(0); setegid(0)`.
5. Privileged filesystem operations fall back to `mpRootHelper` if standard POSIX operations encounter permission barriers (`EACCES`).
