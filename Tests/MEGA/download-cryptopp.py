"""Fetch the pinned official Crypto++ binary in parallel ranges and verify its SHA-256.

Build-time helper only; uses curl's configured proxy/TLS trust without changing either.
"""
import concurrent.futures
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

URL = "https://s3.g.s4.mega.io/dmlaaezwz52y37atz56mfvmrvltfagrltbgpr/xcframeworks-macos-support/libcryptopp.xcframework.zip"
SIZE = 98873190
SHA256 = "f7483596a4a682fbdf38a2a0c919c6407bdbd8c4f3cef1877c105820ae9f9896"
CHUNK = 4 * 1024 * 1024
output = Path(os.environ.get("MEGA_DOWNLOAD_CACHE", "/private/tmp")) / "wakemusic-mega-libcryptopp-parallel.zip"

with tempfile.TemporaryDirectory(prefix="wakemusic-mega-ranges-") as directory:
    work = Path(directory)

    def fetch(start):
        end = min(start + CHUNK, SIZE) - 1
        part = work / str(start)
        subprocess.run(["curl", "--fail", "--location", "--silent", "--show-error",
                        "--retry", "2", "--connect-timeout", "15", "--max-time", "300",
                        "--range", f"{start}-{end}", URL, "-o", str(part)], check=True)
        if part.stat().st_size != end - start + 1:
            raise RuntimeError("Server returned an unexpected range length")
        print(f"Downloaded range {start}-{end}", flush=True)
        return part

    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        parts = list(pool.map(fetch, range(0, SIZE, CHUNK)))
    combined = work / "verified.zip"
    digest = hashlib.sha256()
    with combined.open("wb") as target:
        for part in parts:
            with part.open("rb") as source:
                while data := source.read(1024 * 1024):
                    digest.update(data)
                    target.write(data)
    if digest.hexdigest() != SHA256:
        raise RuntimeError("Official SDK checksum mismatch; refusing to install")
    shutil.move(str(combined), output)
    print(f"Verified official archive: {output}", flush=True)
