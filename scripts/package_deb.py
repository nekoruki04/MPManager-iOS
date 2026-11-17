#!/usr/bin/env python3
import os
import sys
import tarfile
import tempfile
import subprocess
import shutil
import argparse

def make_tar_gz(source_dir, output_file, is_control=False):
    with tarfile.open(output_file, "w:gz", format=tarfile.GNU_FORMAT) as tar:
        for root, dirs, files in os.walk(source_dir):
            rel_dir = os.path.relpath(root, source_dir)
            if rel_dir == ".":
                dir_entry = "."
            else:
                dir_entry = "./" + rel_dir
            
            tar_info = tar.gettarinfo(root, arcname=dir_entry)
            tar_info.uid = 0
            tar_info.gid = 0
            tar_info.uname = "root"
            tar_info.gname = "wheel"
            if not is_control and rel_dir != ".":
                tar_info.mode = 0o755
            tar.addfile(tar_info)

            for f in files:
                full_path = os.path.join(root, f)
                if rel_dir == ".":
                    arcname = "./" + f
                else:
                    arcname = "./" + os.path.join(rel_dir, f)
                
                tar_info = tar.gettarinfo(full_path, arcname=arcname)
                tar_info.uid = 0
                tar_info.gid = 0
                tar_info.uname = "root"
                tar_info.gname = "wheel"
                
                if is_control:
                    if f in ["postinst", "prerm", "postrm", "preinst"]:
                        tar_info.mode = 0o755
                    else:
                        tar_info.mode = 0o644
                else:
                    if f in ["MPManager", "mpRootHelper"]:
                        tar_info.mode = 0o4755
                    elif os.access(full_path, os.X_OK):
                        tar_info.mode = 0o755
                    else:
                        tar_info.mode = 0o644
                
                if tar_info.isreg():
                    with open(full_path, "rb") as fp:
                        tar.addfile(tar_info, fp)
                else:
                    tar.addfile(tar_info)

def main():
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

    parser = argparse.ArgumentParser(description="Package MP Manager into Dopamine rootless .deb")
    parser.add_argument("--app", help="Path to MPManager.app", required=True)
    parser.add_argument("--debian", help="Path to DEBIAN directory", default=None)
    parser.add_argument("--entitlements", help="Path to entitlements plist", default=None)
    parser.add_argument("--output", help="Output path for .deb package", default=None)
    args = parser.parse_args()

    app_source = os.path.abspath(args.app)
    assert os.path.isdir(app_source), f"Built application bundle not found: {app_source}"

    debian_dir = os.path.abspath(args.debian or os.path.join(repo_root, "Packaging", "DEBIAN"))
    assert os.path.isdir(debian_dir), f"DEBIAN directory not found: {debian_dir}"

    entitlements = os.path.abspath(args.entitlements or os.path.join(repo_root, "Packaging", "MPManager.entitlements"))
    build_dir = os.path.abspath(os.path.join(repo_root, "..", "build"))
    os.makedirs(build_dir, exist_ok=True)
    
    primary_deb = os.path.abspath(args.output or os.path.join(build_dir, "mpmanager-rootless_1.1.1_iphoneos-arm.deb"))
    
    with tempfile.TemporaryDirectory() as tmpdir:
        staging_dir = os.path.join(tmpdir, "staging")
        app_dest = os.path.join(staging_dir, "var", "jb", "Applications", "MPManager.app")
        os.makedirs(app_dest, exist_ok=True)
        
        print(f"[*] Copying {app_source} to {app_dest}...")
        subprocess.check_call(["rsync", "-a", app_source.rstrip("/") + "/", app_dest.rstrip("/") + "/"])
        
        for bin_name in ["MPManager", "mpRootHelper"]:
            bin_path = os.path.join(app_dest, bin_name)
            if os.path.isfile(bin_path):
                print(f"[*] Setting minos to 16.0 on {bin_path}...")
                subprocess.check_call(["vtool", "-set-build-version", "ios", "16.0", "18.5", "-replace", "-output", bin_path, bin_path])
                if os.path.isfile(entitlements):
                    print(f"[*] Signing {bin_path} with {entitlements}...")
                    subprocess.check_call(["ldid", f"-S{entitlements}", bin_path])
        
        control_tar = os.path.join(tmpdir, "control.tar.gz")
        data_tar = os.path.join(tmpdir, "data.tar.gz")
        
        print("[*] Generating control.tar.gz...")
        make_tar_gz(debian_dir, control_tar, is_control=True)
        
        print("[*] Generating data.tar.gz...")
        make_tar_gz(staging_dir, data_tar, is_control=False)
        
        debian_binary = os.path.join(tmpdir, "debian-binary")
        with open(debian_binary, "wb") as f:
            f.write(b"2.0\n")
            
        print(f"[*] Assembling Debian package -> {primary_deb}...")
        if os.path.exists(primary_deb):
            os.remove(primary_deb)
        subprocess.check_call(["/usr/bin/ar", "-rc", primary_deb, debian_binary, control_tar, data_tar], cwd=tmpdir)
            
    print(f"[+] Package created successfully: {primary_deb} ({os.path.getsize(primary_deb)} bytes)")

if __name__ == "__main__":
    main()
