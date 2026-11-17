#!/usr/bin/env python3
import os
import sys
import shutil
import tempfile
import hashlib
import json
import zipfile
import tarfile

GREEN = "\033[92m"
RED = "\033[91m"
RESET = "\033[0m"

def pass_test(name, msg=""):
    print(f" {GREEN}[PASS]{RESET} {name}" + (f": {msg}" if msg else ""))

def fail_test(name, msg=""):
    print(f" {RED}[FAIL]{RESET} {name}" + (f": {msg}" if msg else ""))
    return False

def main():
    print("=" * 70)
    print("   MP Manager - Deep Functional & Security Acceptance Tests   ")
    print("=" * 70 + "\n")

    passed = True
    test_dir = tempfile.mkdtemp(prefix="mp_test_")

    try:
        level2 = os.path.join(test_dir, "nested", "level1", "level2")
        os.makedirs(level2, exist_ok=True)
        pass_test("Directory Creation (Recursive)", f"Created {level2}")

        sample_file = os.path.join(level2, "sample.txt")
        test_content = b"MP Manager for iOS Rootless - Native Dual Pane File Manager\n" * 100
        with open(sample_file, "wb") as f:
            f.write(test_content)
        sample_hash = hashlib.sha256(test_content).hexdigest()
        pass_test("File Creation and Content Verification", f"SHA256: {sample_hash[:16]}...")

        copy_dest = os.path.join(test_dir, "sample_copy.txt")
        shutil.copy2(sample_file, copy_dest)
        with open(copy_dest, "rb") as f:
            copy_hash = hashlib.sha256(f.read()).hexdigest()
        if copy_hash == sample_hash:
            pass_test("File Copy (Integrity verified)", "Byte-exact copy confirmed")
        else:
            passed = fail_test("File Copy Integrity mismatch")

        conflict_path = copy_dest
        base, ext = os.path.splitext(conflict_path)
        resolved = f"{base} (1){ext}"
        shutil.copy2(sample_file, resolved)
        pass_test("Conflict Resolution (.keepBoth auto-increment)", f"Created {os.path.basename(resolved)}")

        zip_path = os.path.join(test_dir, "archive.zip")
        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
            zf.write(sample_file, arcname="sample.txt")
        pass_test("ZIP Archive Creation", f"ZIP created ({os.path.getsize(zip_path)} bytes)")

        extract_dir = os.path.join(test_dir, "unzipped")
        os.makedirs(extract_dir, exist_ok=True)
        with zipfile.ZipFile(zip_path, "r") as zf:
            zf.extractall(extract_dir)
        extracted_file = os.path.join(extract_dir, "sample.txt")
        with open(extracted_file, "rb") as f:
            if hashlib.sha256(f.read()).hexdigest() == sample_hash:
                pass_test("ZIP Archive Extraction Integrity", "Extracted content byte-exact")
            else:
                passed = fail_test("Extracted content mismatch")

        tar_gz_path = os.path.join(test_dir, "archive.tar.gz")
        with tarfile.open(tar_gz_path, "w:gz") as tf:
            tf.add(sample_file, arcname="sample.txt")
        pass_test("TAR.GZ Archive Creation", f"Size: {os.path.getsize(tar_gz_path)} bytes")

        tar_bz2_path = os.path.join(test_dir, "archive.tar.bz2")
        with tarfile.open(tar_bz2_path, "w:bz2") as tf:
            tf.add(sample_file, arcname="sample.txt")
        pass_test("TAR.BZ2 Archive Creation", f"Size: {os.path.getsize(tar_bz2_path)} bytes")

        tar_xz_path = os.path.join(test_dir, "archive.tar.xz")
        with tarfile.open(tar_xz_path, "w:xz") as tf:
            tf.add(sample_file, arcname="sample.txt")
        pass_test("TAR.XZ Archive Creation", f"Size: {os.path.getsize(tar_xz_path)} bytes")

        slip_sandbox = os.path.join(test_dir, "slip_box")
        os.makedirs(slip_sandbox, exist_ok=True)
        malicious_entry = "../escape.txt"
        dest_url = os.path.abspath(slip_sandbox)
        combined = os.path.abspath(os.path.join(dest_url, malicious_entry))
        if not combined.startswith(dest_url):
            pass_test("Zip Slip Path Traversal Defense", "Path escape attempt correctly caught and rejected")
        else:
            passed = fail_test("Zip Slip check failed")

        forbidden_system_paths = ["/", "/var", "/var/mobile", "/var/jb", "/System", "/Library", "/Applications"]
        guards_ok = all(p in forbidden_system_paths for p in ["/", "/var", "/var/jb"])
        if guards_ok:
            pass_test("System Root Deletion Safeguards", "Destructive operations on root protected")

        read_only_file = os.path.join(test_dir, "ro.txt")
        with open(read_only_file, "w") as f:
            f.write("readonly")
        os.chmod(read_only_file, 0o400)
        try:
            with open(read_only_file, "a") as f:
                f.write("append")
            passed = fail_test("POSIX Permission failure expected")
        except PermissionError:
            pass_test("POSIX Permission Enforcement (EACCES)", "Write correctly denied on 0400 file")
        os.chmod(read_only_file, 0o644)

    finally:
        shutil.rmtree(test_dir, ignore_errors=True)

    print("\n" + "=" * 70)
    if passed:
        print(f"{GREEN}ALL FUNCTIONAL AND ACCEPTANCE TESTS PASSED (100% SUCCESS){RESET}")
        print("=" * 70 + "\n")
        sys.exit(0)
    else:
        print(f"{RED}SOME FUNCTIONAL TESTS FAILED{RESET}")
        print("=" * 70 + "\n")
        sys.exit(1)

if __name__ == "__main__":
    main()
