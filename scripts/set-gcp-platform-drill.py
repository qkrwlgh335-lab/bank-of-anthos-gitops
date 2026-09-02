#!/usr/bin/env python3
"""Select one immutable release and toggle the DB-independent GCP probe."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


SERVICES = (
    "frontend",
    "userservice",
    "contacts",
    "balancereader",
    "ledgerwriter",
    "transactionhistory",
)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--probe-replicas", type=int, choices=(0, 1), required=True)
    args = parser.parse_args()

    if not re.fullmatch(r"sha-[0-9a-f]{40}", args.tag):
        raise SystemExit("tag must be sha- followed by a 40-character Git commit SHA")

    path = Path(args.file)
    content = path.read_text(encoding="utf-8")

    for service in SERVICES:
        pattern = re.compile(
            rf"(\n\s*- name: .*\/{service}\n\s+newName: .*\/{service}\n\s+newTag:)\s*[^\n]+"
        )
        content, count = pattern.subn(rf"\g<1> {args.tag}", content, count=1)
        if count != 1:
            raise SystemExit(f"missing or duplicate GCP image entry: {service}")

    probe_pattern = re.compile(
        r"(\n\s*- name: dr-platform-probe\n\s+count:)\s*\d+"
    )
    content, count = probe_pattern.subn(
        rf"\g<1> {args.probe_replicas}", content, count=1
    )
    if count != 1:
        raise SystemExit("missing or duplicate dr-platform-probe replica entry")

    path.write_text(content, encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
