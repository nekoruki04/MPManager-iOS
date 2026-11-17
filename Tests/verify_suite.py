#!/usr/bin/env python3
import os
import sys
import tarfile
import subprocess
import tempfile
import plistlib
import io

GREEN = "\033[92m"
RED = "\033[91m"
RESET = "\033[0m"

def check(name, condition, details=""):
    if condition:
        print(f" {GREEN}[PASS]{RESET} {name}" + (f" -> {details}" if details else ""))
        return True
    else:
        print(f" {RED}[FAIL]{RESET} {name}" + (f" -> {details}" if details else ""))
        return False

def main():
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    build_dir = os.path.abspath(os.path.join(repo_root, "..", "build"))
    deb_path = os.path.join(build_dir, "mpmanager-rootless_1.0.0_iphoneos-arm.deb")

    print("=" * 70)
    print("   MP Manager for iOS — Verification & Acceptance Test Suite   ")
    print("=" * 70)
    print(f"Target deb: {deb_path}\n")

    if not os.path.isfile(deb_path):
        print(f"{RED}Error: Package file not found at {deb_path}{RESET}")
        sys.exit(1)

    all_passed = True

    with open(deb_path, "rb") as f:
        content = f.read()

    all_passed &= check("Package Unix ar format", content.startswith(b"!<arch>\n"))
    all_passed &= check("Contains debian-binary", b"debian-binary" in content)
    all_passed &= check("Contains control.tar.gz", b"control.tar.gz" in content)
    all_passed &= check("Contains data.tar.gz", b"data.tar.gz" in content)

    data_idx = content.find(b"data.tar.gz")
    hdr = content[data_idx:data_idx+60]
    size = int(hdr[48:58].strip())
    raw_tar = content[data_idx+60:data_idx+60+size]

    with tempfile.TemporaryDirectory() as tmpdir:
        with tarfile.open(fileobj=io.BytesIO(raw_tar), mode="r:gz") as tar:
            tar.extractall(tmpdir)
            members = {m.name: m for m in tar.getmembers()}

        app_dir = os.path.join(tmpdir, "var", "jb", "Applications", "MPManager.app")
        all_passed &= check("Rootless installation path (/var/jb/Applications/MPManager.app)", os.path.isdir(app_dir))

        mp_bin = os.path.join(app_dir, "MPManager")
        helper_bin = os.path.join(app_dir, "mpRootHelper")
        all_passed &= check("Main binary exists", os.path.isfile(mp_bin))
        all_passed &= check("Root helper binary exists", os.path.isfile(helper_bin))

        m_mp = members.get("./var/jb/Applications/MPManager.app/MPManager")
        m_hlp = members.get("./var/jb/Applications/MPManager.app/mpRootHelper")
        all_passed &= check("MPManager setuid root (04755)", m_mp and (m_mp.mode == 0o4755) and m_mp.uid == 0)
        all_passed &= check("mpRootHelper setuid root (04755)", m_hlp and (m_hlp.mode == 0o4755) and m_hlp.uid == 0)

        file_out = subprocess.check_output(["file", mp_bin]).decode()
        all_passed &= check("Mach-O 64-bit arm64 slice", "Mach-O 64-bit executable arm64" in file_out)

        vtool_out = subprocess.check_output(["xcrun", "vtool", "-show-build", mp_bin]).decode()
        all_passed &= check("Platform deployment target iOS 16.0", "minos 16.0" in vtool_out)

        ldid_out = subprocess.check_output(["ldid", "-e", mp_bin]).decode()
        all_passed &= check("Entitlements: no-sandbox", "com.apple.private.security.no-sandbox" in ldid_out)
        all_passed &= check("Entitlements: platform-application", "platform-application" in ldid_out)

    print("\n" + "=" * 70)
    if all_passed:
        print(f"{GREEN}ALL VERIFICATION CHECKS PASSED (100% SUCCESS){RESET}")
        print("=" * 70 + "\n")
        sys.exit(0)
    else:
        print(f"{RED}SOME VERIFICATION CHECKS FAILED{RESET}")
        print("=" * 70 + "\n")
        sys.exit(1)

if __name__ == "__main__":
    main()
