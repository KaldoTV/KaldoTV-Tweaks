#!/usr/bin/env python3
"""Update the addon's TOC Version metadata."""

from __future__ import annotations

import argparse
import re
from datetime import datetime, timezone
from pathlib import Path


VERSION_RE = re.compile(r"^(## Version:\s*)(\S+)(\s*)$", re.MULTILINE)
DATE_SUFFIX_RE = re.compile(r"-\d{8}$")


def read_current_version(toc_path: Path) -> str:
    text = toc_path.read_text(encoding="utf-8")
    match = VERSION_RE.search(text)
    if not match:
        raise RuntimeError(f"could not find '## Version:' in {toc_path}")
    return match.group(2)


def base_version(version: str) -> str:
    version = version.strip()
    if version.startswith("v"):
        version = version[1:]
    return DATE_SUFFIX_RE.sub("", version)


def write_version(toc_path: Path, version: str) -> None:
    text = toc_path.read_text(encoding="utf-8")
    updated, count = VERSION_RE.subn(rf"\g<1>{version}\g<3>", text, count=1)
    if count != 1:
        raise RuntimeError(f"could not update '## Version:' in {toc_path}")
    toc_path.write_text(updated, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--toc", default="kaldo_tweaks.toc", type=Path)
    parser.add_argument("--version", help="Exact version to write. Leading 'v' is stripped.")
    parser.add_argument("--daily", action="store_true", help="Append today's UTC date to the current base version.")
    parser.add_argument("--base-version", help="Base version to use with --daily. Leading 'v' and date suffix are stripped.")
    parser.add_argument("--print-only", action="store_true", help="Print the computed version without updating the TOC.")
    args = parser.parse_args()

    if args.version and args.daily:
        parser.error("--version and --daily are mutually exclusive")

    if args.version:
        version = base_version(args.version)
    elif args.daily:
        base = args.base_version or read_current_version(args.toc)
        version = f"{base_version(base)}-{datetime.now(timezone.utc):%Y%m%d}"
    else:
        parser.error("pass --version or --daily")

    if not args.print_only:
        write_version(args.toc, version)
    print(version)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
