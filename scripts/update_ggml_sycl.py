#!/usr/bin/env python3
"""
Script to update local ggml-sycl sources from the latest GitHub llama.cpp
"""

import os
import sys
import json
import hashlib
import shutil
from pathlib import Path
from urllib import request
from datetime import datetime

# Configuration
# Find project root based on script location
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
TARGET_DIR = PROJECT_ROOT / "ml/backend/ggml/ggml/src/ggml-sycl"

GITHUB_API_URL = "https://api.github.com/repos/ggml-org/llama.cpp/contents/ggml/src/ggml-sycl?ref=master"
GITHUB_RAW_BASE = "https://raw.githubusercontent.com/ggml-org/llama.cpp/master/ggml/src/ggml-sycl"

def get_file_sha(file_path):
    """Calculate Git-style SHA-1 hash"""
    if not file_path.exists():
        return None
    
    with open(file_path, 'rb') as f:
        data = f.read()
    
    # Git object format: "blob {size}\0{content}"
    blob = f"blob {len(data)}\0".encode() + data
    return hashlib.sha1(blob).hexdigest()

def download_file(url, dest_path):
    """Download file"""
    try:
        with request.urlopen(url) as response:
            data = response.read()
        with open(dest_path, 'wb') as f:
            f.write(data)
        return True
    except Exception as e:
        print(f"  ✗ Download failed: {e}")
        return False

def main():
    print("=== GGML SYCL Update Started ===")
    print(f"Target directory: {TARGET_DIR}")
    print()
    
    # Get file list from GitHub API
    print("Fetching file list from GitHub...")
    try:
        with request.urlopen(GITHUB_API_URL) as response:
            files_info = json.loads(response.read())
    except Exception as e:
        print(f"✗ API request failed: {e}")
        return 1
    
    # Create backup directory
    backup_dir = Path(f"/tmp/ggml_sycl_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}")
    backup_dir.mkdir(parents=True, exist_ok=True)
    
    # Statistics
    stats = {
        'updated': [],
        'new': [],
        'unchanged': [],
        'failed': []
    }
    
    # Process each file
    for file_info in files_info:
        if file_info['type'] == 'dir':
            # Skip directories for now
            continue
        
        file_name = file_info['name']
        github_sha = file_info['sha']
        download_url = file_info['download_url']
        
        local_file = TARGET_DIR / file_name
        local_sha = get_file_sha(local_file) if local_file.exists() else None
        
        # Compare SHA
        if local_sha == github_sha:
            print(f"  Unchanged: {file_name}")
            stats['unchanged'].append(file_name)
        else:
            # Backup (if existing file exists)
            if local_file.exists():
                shutil.copy2(local_file, backup_dir / file_name)
                status = "Updated"
                stats['updated'].append(file_name)
            else:
                status = "New file"
                stats['new'].append(file_name)
            
            # Download
            print(f"✓ {status}: {file_name}")
            temp_file = Path(f"/tmp/{file_name}")
            
            if download_file(download_url, temp_file):
                # Verify downloaded file SHA
                downloaded_sha = get_file_sha(temp_file)
                if downloaded_sha == github_sha:
                    shutil.move(str(temp_file), str(local_file))
                else:
                    print(f"  ⚠ SHA mismatch: {file_name} (expected: {github_sha}, actual: {downloaded_sha})")
                    stats['failed'].append(file_name)
                    if temp_file.exists():
                        temp_file.unlink()
            else:
                stats['failed'].append(file_name)
    
    # Process dpct directory
    print()
    print("=== Processing dpct directory ===")
    dpct_dir = TARGET_DIR / "dpct"
    dpct_dir.mkdir(exist_ok=True)
    
    # Download dpct/helper.hpp
    dpct_helper_url = f"{GITHUB_RAW_BASE}/dpct/helper.hpp"
    dpct_helper_file = dpct_dir / "helper.hpp"
    
    if download_file(dpct_helper_url, dpct_helper_file):
        print("✓ dpct/helper.hpp download completed")
    else:
        print("  dpct/helper.hpp download failed (file may not exist)")
    
    # Print statistics
    print()
    print("=== Update Completed ===")
    print(f"New files: {len(stats['new'])}")
    if stats['new']:
        for f in stats['new']:
            print(f"  + {f}")
    
    print(f"\nUpdated: {len(stats['updated'])}")
    if stats['updated']:
        for f in stats['updated']:
            print(f"  ↻ {f}")
    
    print(f"\nUnchanged: {len(stats['unchanged'])}")
    
    if stats['failed']:
        print(f"\nFailed: {len(stats['failed'])}")
        for f in stats['failed']:
            print(f"  ✗ {f}")
    
    print(f"\nBackup location: {backup_dir}")
    
    # Remove backup directory if empty
    if not any(backup_dir.iterdir()):
        backup_dir.rmdir()
        print("(No backup created since there were no changes)")
    
    return 0 if not stats['failed'] else 1

if __name__ == "__main__":
    sys.exit(main())
