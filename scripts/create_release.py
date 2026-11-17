import urllib.request
import json
import subprocess
import os

res = subprocess.check_output(['git', 'credential', 'fill'], input=b'protocol=https\nhost=github.com\n')
token = ''
for line in res.decode().splitlines():
    if line.startswith('password='):
        token = line.split('=', 1)[1]

deb_path = 'build/mpmanager-rootless_1.1.0_iphoneos-arm.deb'
deb_size = os.path.getsize(deb_path)
with open('build/checksums_mpmanager.txt', 'r') as f:
    checksum = f.read().strip()

sha256_hash = checksum.split()[0]

release_body = f"""# MP Manager for iOS v1.1.0 (Dopamine Rootless)

A free, native dual-pane file manager, APK/binary reverse engineering suite, and MCP server for iOS designed specifically for jailbroken devices running **Dopamine 2**, **Dopamine 3**, and **RootHide**.

Direct native port of the open-source [MP Manager](https://github.com/AbdurazaaqMohammed/MP-Manager) by Abdurazaaq Mohammed, faithfully replicating MT Manager's dual-pane paradigm on iOS with full rootless jailbreak privileges.

---

### What's New in v1.1.0
- **Media Suite**:
  - Built-in Audio & Video player (`AudioVideoPlayerViewController`) with `AVPlayer`, seek slider, play/pause, 10s skip, time labels, and background playback.
  - Image viewer & editor (`ImageViewerViewController`) with directory swipe navigation, pinch-to-zoom, EXIF metadata inspector, 90° rotate, flip, and private EXIF data stripping (**Strip EXIF**).
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
- **Real-device preview screenshots added to repository documentation.**

---

### Package Details & Checksums
- **Package:** `mpmanager-rootless_1.1.0_iphoneos-arm.deb` ({deb_size:,} bytes)
- **SHA-256:** `{sha256_hash}`

---

### Installation
```bash
dpkg -i mpmanager-rootless_1.1.0_iphoneos-arm.deb
uicache -p /var/jb/Applications/MPManager.app
```
Or open and install via **Sileo** or **Zebra**.
"""

tag = "v1.1.0"
api_base = "https://api.github.com/repos/nekoruki04/MPManager-iOS/releases"

req = urllib.request.Request(
    f"{api_base}/tags/{tag}",
    headers={
        'Authorization': f'token {token}',
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'MPManager-iOS'
    }
)

release_data = None
try:
    with urllib.request.urlopen(req) as resp:
        release_data = json.loads(resp.read().decode())
except urllib.error.HTTPError as e:
    if e.code == 404:
        create_payload = {
            "tag_name": tag,
            "target_commitish": "main",
            "name": f"MP Manager for iOS {tag}",
            "body": release_body,
            "draft": False,
            "prerelease": False
        }
        create_req = urllib.request.Request(
            api_base,
            data=json.dumps(create_payload).encode(),
            headers={
                'Authorization': f'token {token}',
                'Accept': 'application/vnd.github.v3+json',
                'User-Agent': 'MPManager-iOS'
            },
            method='POST'
        )
        with urllib.request.urlopen(create_req) as resp:
            release_data = json.loads(resp.read().decode())
            print(f"Created release {tag}")
    else:
        raise

release_id = release_data['id']
upload_url_tmpl = release_data['upload_url']

patch_req = urllib.request.Request(
    f"{api_base}/{release_id}",
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

assets = release_data.get('assets', [])
for a in assets:
    if a['name'] == 'mpmanager-rootless_1.1.0_iphoneos-arm.deb':
        del_req = urllib.request.Request(
            f"{api_base}/assets/{a['id']}",
            headers={
                'Authorization': f'token {token}',
                'Accept': 'application/vnd.github.v3+json',
                'User-Agent': 'MPManager-iOS'
            },
            method='DELETE'
        )
        urllib.request.urlopen(del_req)
        print("Deleted existing asset")

upload_url = upload_url_tmpl.replace('{?name,label}', '?name=mpmanager-rootless_1.1.0_iphoneos-arm.deb')
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
