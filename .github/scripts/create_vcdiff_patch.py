#!/usr/bin/env python3
import argparse
import hashlib
import json
import subprocess
from pathlib import Path


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def create_patch(
    old_path: Path,
    new_path: Path,
    output_path: Path,
    from_version_code: int,
    to_version_code: int,
) -> dict:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "xdelta3",
            "-e",
            "-S",
            "none",
            "-s",
            str(old_path),
            str(new_path),
            str(output_path),
        ],
        check=True,
    )

    return {
        "assetName": output_path.name,
        "algorithm": "vcdiff",
        "patchFormat": "vcdiff",
        "fromVersionCode": from_version_code,
        "toVersionCode": to_version_code,
        "sha256": sha256_file(output_path),
        "size": output_path.stat().st_size,
        "oldSha256": sha256_file(old_path),
        "newSha256": sha256_file(new_path),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Create Trace VCDIFF APK patch with xdelta3")
    parser.add_argument("old_apk", type=Path)
    parser.add_argument("new_apk", type=Path)
    parser.add_argument("output_patch", type=Path)
    parser.add_argument("--from-version-code", type=int, required=True)
    parser.add_argument("--to-version-code", type=int, required=True)
    parser.add_argument("--metadata-output", type=Path)
    args = parser.parse_args()

    metadata = create_patch(
        args.old_apk,
        args.new_apk,
        args.output_patch,
        args.from_version_code,
        args.to_version_code,
    )
    if args.metadata_output:
        args.metadata_output.write_text(
            json.dumps(metadata, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
    else:
        print(json.dumps(metadata, ensure_ascii=False))


if __name__ == "__main__":
    main()
