import urllib.request
import json
import subprocess
import os

res = subprocess.check_output(['git', 'credential', 'fill'], input=b'protocol=https\nhost=github.com\n')
token = ''
for line in res.decode().splitlines():
    if line.startswith('password='):
        token = line.split('=', 1)[1]

deb_path = 'build/mpmanager-rootless_1.1.3_iphoneos-arm.deb'
deb_size = os.path.getsize(deb_path)
with open('build/checksums_mpmanager.txt', 'r') as f:
    checksum = f.read().strip()

sha256_hash = checksum.split()[0]

release_body = f"""# MP Manager for iOS v1.1.3 (Dopamine Rootless)

A free, native dual-pane file manager, APK/binary reverse engineering suite, and MCP server for iOS designed specifically for jailbroken devices running **Dopamine 2**, **Dopamine 3**, and **RootHide**.

Direct native port of the open-source [MP Manager](https://github.com/AbdurazaaqMohammed/MP-Manager) by Abdurazaaq Mohammed, faithfully replicating MT Manager's dual-pane paradigm on iOS with full rootless jailbreak privileges.

---

### What's New in v1.1.3
- **ZIP Extraction & Archive Engine (`NativeZipEngine`)**:
  - Implemented standard PKZIP Central Directory parser (`0x02014b50`) and End of Central Directory locator (`0x06054b50`).
  - Fixed extraction failure on ZIP files with streaming data descriptors (General Purpose Bit 3 `0x0008`) where local header sizes are zero.
  - Added robust chunk-streaming Deflate inflation (`Z_NO_FLUSH` via Darwin kernel `zlib`).
  - Restructured archive extraction pipeline in `ArchiveManager`: prioritized `.zip` / `.apk` processing before tar checks, eliminating "tar binary not found" errors on devices without `tar`.
  - Multi-tier extraction fallback: `NativeZipEngine` $\to$ `/usr/bin/ditto -x -k` $\to$ `unzip`.
- **Dynamic Rootless Jailbreak Resolution (`RootlessPaths`)**:
  - Automatically extracts container-based rootless jailbreak paths (`.jbroot-*`) directly from `Bundle.main.bundlePath` on modern iOS versions (iOS 16–18).
  - Dynamic shell resolver (`RootlessPaths.resolve_shell()`) and complete rootless environment `PATH` configuration (`<jbroot>/usr/bin:<jbroot>/bin:/var/jb/usr/bin:/var/jb/bin:/usr/bin:/bin`).
- **Fixed Crash on Opening "Installed Apps & Containers"**:
  - Eliminated unsafe Objective-C dynamic reflection (`_applicationIconImageForBundleIdentifier:format:scale:`) that caused `EXC_BAD_ACCESS` / uncaught exceptions on background view services and system daemons.
  - Implemented safe, multi-tier native icon extraction via `.app` bundle directory scans and `Bundle(path:)` asset lookups with zero crash risk.
  - Fixed empty application names (` (1.0)`) for system daemons; cleanly falls back to bundle folder name.
  - Added categorized, tinted SF Symbol placeholders (`terminal` for Jailbreak, `applelogo` for System, `app.gift` for User apps) when no asset exists.
- **Universal iPadOS ActionSheet Crash Prevention (`present_adaptive_sheet`)**:
  - Configured safe `popoverPresentationController` anchoring across all `UIAlertController(preferredStyle: .actionSheet)` views to prevent `NSGenericException` crashes on iPad Pro and iPadOS.

---

### Package Details & Checksums
- **Package:** `mpmanager-rootless_1.1.3_iphoneos-arm.deb` ({deb_size:,} bytes)
- **SHA-256:** `{sha256_hash}`

---

### Installation
```bash
dpkg -i mpmanager-rootless_1.1.3_iphoneos-arm.deb
uicache -p /var/jb/Applications/MPManager.app
```
Or open and install via **Sileo** or **Zebra**.
"""

tag = "v1.1.3"
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
    if a['name'] == 'mpmanager-rootless_1.1.3_iphoneos-arm.deb':
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

upload_url = upload_url_tmpl.replace('{?name,label}', '?name=mpmanager-rootless_1.1.3_iphoneos-arm.deb')
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
