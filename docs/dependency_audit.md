# MP Manager Upstream Dependency Audit & License Compliance

## 1. Upstream License Analysis
- **MP Manager Main Application:** GNU General Public License v3.0 (GPLv3).
- **Amaze File Manager & Tools:** GPLv3.
- **commons-compress:** Apache License 2.0.
- **jadx-core:** Apache License 2.0.
- **bouncycastle:** Bouncy Castle License (MIT-compatible).
- **Sora Editor:** LGPL v2.1.
- **zip4j:** Apache License 2.0.
- **java-diff-utils:** Apache License 2.0.

All dependencies and ported logic are fully compatible with GPLv3.
The ported iOS project will be licensed under **GNU General Public License v3.0 (GPLv3)**.

---

## 2. Porting Strategy for Core Dependencies

| Dependency | Original Role | iOS Port Approach |
|---|---|---|
| **commons-compress** | Archive creation & extraction | Native C/POSIX archive pipeline (`tar`, `bsdtar`, `unzip`, `7z`) + streaming buffers |
| **jadx-core / dex2jar** | Dex disassembly | Lightweight native DEX parser (inspecting classes, methods, fields, strings) |
| **arsc-parser / axml** | Resource & manifest decode | Native Swift AXML & ARSC string pool parser |
| **commons-net / smbj** | FTP / FTPS / SMB | Real POSIX / curl network backend with secure Keychain credential storage |
| **bouncycastle** | Cryptography & Keystores | Native CryptoKit + CommonCrypto AES-GCM 256-bit & PBKDF2 |
| **Sora Editor** | Syntax-highlighting code editor | Native UIKit TextKit editor with monospaced font, line numbers & Find/Replace |
| **NanoHTTPD** | Local MCP Server | Native Swift HTTP 1.1 / SSE daemon on port 8787 |
| **java-diff-utils** | Text comparison | Native Swift Myers diff algorithm |
