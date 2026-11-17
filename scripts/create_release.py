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
- **Model Context Protocol (MCP) Server**: Embedded local HTTP/SSE daemon at `http://127.0.0.1:8787/mcp` for local and networked AI agent interaction.
- **Network Storage**: Connect to `FTP`, `FTPS`, `SFTP`, and `WebDAV` with hardware-backed iOS Keychain security.

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

release_payload = {
    'tag_name': 'v1.0.0',
    'name': 'MP Manager for iOS v1.0.0 (Dopamine Rootless)',
    'body': release_body,
    'draft': False,
    'prerelease': False
}

req = urllib.request.Request(
    'https://api.github.com/repos/nekoruki04/MPManager-iOS/releases',
    data=json.dumps(release_payload).encode(),
    headers={
        'Authorization': f'token {token}',
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'MPManager-iOS'
    },
    method='POST'
)

with urllib.request.urlopen(req) as resp:
    rel_data = json.loads(resp.read().decode())
    upload_url_tmpl = rel_data.get('upload_url')
    html_url = rel_data.get('html_url')
    print('Created Release:', html_url)

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
    print('Uploaded asset:', asset_data.get('browser_download_url'))
