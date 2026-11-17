import urllib.request
import json
import subprocess
import os

res = subprocess.check_output(['git', 'credential', 'fill'], input=b'protocol=https\nhost=github.com\n')
token = ''
for line in res.decode().splitlines():
    if line.startswith('password='):
        token = line.split('=', 1)[1]

deb_path = 'build/mpmanager-rootless_1.0.0_iphoneos-arm.deb'
deb_size = os.path.getsize(deb_path)
with open('build/checksums_mpmanager.txt', 'r') as f:
    checksum = f.read().strip()

sha256_hash = checksum.split()[0]

release_body = f"""# MP Manager for iOS v1.0.0 (Dopamine Rootless)

A free, native dual-pane file manager, APK/binary reverse engineering suite, and MCP server for iOS designed specifically for jailbroken devices running **Dopamine 2**, **Dopamine 3**, and **RootHide**.

Direct native port of the open-source [MP Manager](https://github.com/AbdurazaaqMohammed/MP-Manager) by Abdurazaaq Mohammed, faithfully replicating MT Manager's dual-pane paradigm on iOS with full rootless jailbreak privileges.

---

### Features & Highlights
- **Dual-Pane Interface**: Side-by-side independent navigation panes with active pane accent border highlight (`#2196F3` / `#4CAF50`).
- **Jailbreak Rootless Filesystem**: Direct access to `/var/jb`, `/var/mobile`, `/Library`, `/Applications` via POSIX APIs.
- **Setuid Root Helper**: Bundled `mpRootHelper` (mode `4755`, owned by `0:0`) with automatic privilege escalation.
- **Model Context Protocol (MCP) Server**:
  - Full JSON-RPC 2.0 protocol layer compliant with MCP specification `2024-11-05`.
  - 23 on-device tools (`mp_file_*`, `mp_zip_*`, `mp_apk_*`, `mp_macho_*`, `mp_exec_command`, `mp_network_list`, `mp_ftp_server_status`).
  - Dual transports: Streamable HTTP at `http://<ip>:8787/mcp` and Legacy SSE at `/sse` & `/message`.
  - CORS-enabled with live audit logging and one-click JSON export for Claude Desktop, Cursor, and AI agents.
  - Background task persistence.
- **Comprehensive Network Storage & Wireless File Transfer**:
  - **Built-in FTP Server**: RFC 959 FTP Server over BSD sockets & GCD on port `2121` with anonymous / user authentication, passive mode (PASV/EPSV), file upload/download, and background keepalive.
  - **Native WebDAV Client**: Pure Swift implementation via `URLSession` and `XMLParser` (`PROPFIND` Depth 1, `GET`, `PUT`, `MKCOL`, `DELETE`, `MOVE`).
  - **Remote Files Browser**: Browse remote servers directly inside MP Manager with folder navigation, cross-pane transfers, and direct remote file editing.
  - **Keychain Security**: Remote credentials (FTP, FTPS, SFTP, WebDAV, SMB) encrypted in hardware-backed iOS Keychain.
- **Archive Engine**: In-archive entry listing, selective extraction, and archive creation (ZIP, 7Z, TAR.GZ, TAR.BZ2, TAR.XZ, RAR) with Zip Slip path traversal defense.
- **APK & Binary Tools**:
  - Binary `AndroidManifest.xml` decoder (package, version, SDK constraints).
  - `classes.dex` parser and class count calculator.
  - APK signature scheme verification (V1, V2, V3).
  - Native `Mach-O` and `ELF` binary inspector (`LC_BUILD_VERSION`, segments, linked dylibs).
- **Built-in Editors & Viewers**:
  - **Text Editor**: Monospaced editor with line numbers, regex Find & Replace, and `.bak` backups.
  - **Hex Editor**: Dual-column hex view with ASCII pane and offset jumping.
  - **SQLite Browser**: View table schemas, inspect rows, and run custom queries.
  - **File Comparison (Diff)**: Side-by-side / unified text diff viewer.
  - **Checksum Calculator**: Real-time SHA-256, SHA-1, and MD5 computation.

---

### Package Details & Checksums
- **Package:** `mpmanager-rootless_1.0.0_iphoneos-arm.deb` ({deb_size:,} bytes)
- **SHA-256:** `{sha256_hash}`

---

### Installation
```bash
dpkg -i mpmanager-rootless_1.0.0_iphoneos-arm.deb
uicache -p /var/jb/Applications/MPManager.app
```
Or open and install via **Sileo** or **Zebra**.
"""

req = urllib.request.Request(
    'https://api.github.com/repos/nekoruki04/MPManager-iOS/releases/tags/v1.0.0',
    headers={
        'Authorization': f'token {token}',
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'MPManager-iOS'
    }
)

with urllib.request.urlopen(req) as resp:
    rel_data = json.loads(resp.read().decode())
    release_id = rel_data['id']
    upload_url_tmpl = rel_data['upload_url']
    assets = rel_data.get('assets', [])
    for a in assets:
        if a['name'] == 'mpmanager-rootless_1.0.0_iphoneos-arm.deb':
            del_req = urllib.request.Request(
                f'https://api.github.com/repos/nekoruki04/MPManager-iOS/releases/assets/{a["id"]}',
                headers={
                    'Authorization': f'token {token}',
                    'Accept': 'application/vnd.github.v3+json',
                    'User-Agent': 'MPManager-iOS'
                },
                method='DELETE'
            )
            urllib.request.urlopen(del_req)

patch_req = urllib.request.Request(
    f'https://api.github.com/repos/nekoruki04/MPManager-iOS/releases/{release_id}',
    data=json.dumps({'body': release_body}).encode(),
    headers={
        'Authorization': f'token {token}',
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'MPManager-iOS'
    },
    method='PATCH'
)
with urllib.request.urlopen(patch_req) as resp:
    print('Updated release description')

upload_url = upload_url_tmpl.replace('{?name,label}', '?name=mpmanager-rootless_1.0.0_iphoneos-arm.deb')
with open(deb_path, 'rb') as f:
    deb_bytes = f.read()

upload_req = urllib.request.Request(
    upload_url,
    data=deb_bytes,
    headers={
        'Authorization': f'token {token}',
        'Content-Type': 'application/octet-stream',
        'User-Agent': 'MPManager-iOS'
    },
    method='POST'
)

with urllib.request.urlopen(upload_req) as resp:
    asset_data = json.loads(resp.read().decode())
    print('Uploaded asset:', asset_data.get('browser_download_url'), asset_data.get('size'))
