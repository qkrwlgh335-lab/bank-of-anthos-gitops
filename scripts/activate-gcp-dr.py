#!/usr/bin/env python3
"""Activate the GCP pilot-light overlay after an audited DR approval."""

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
    parser.add_argument("--replicas", type=int, default=1)
    args = parser.parse_args()
    if not re.fullmatch(r"sha-[0-9a-f]{40}", args.tag):
        raise SystemExit("tag must be sha- followed by a 40-character Git commit SHA")
    if args.replicas < 1 or args.replicas > 10:
        raise SystemExit("replicas must be between 1 and 10")

    path = Path(args.file)
    content = path.read_text(encoding="utf-8")
    for service in SERVICES:
        image_pattern = re.compile(
            rf"(\n\s*- name: .*\/{service}\n\s+newName: .*\/{service}\n\s+newTag:)\s*[^\n]+"
        )
        content, image_count = image_pattern.subn(rf"\g<1> {args.tag}", content, count=1)
        replica_pattern = re.compile(rf"(\n\s*- name: {service}\n\s+count:)\s*\d+")
        content, replica_count = replica_pattern.subn(
            rf"\g<1> {args.replicas}", content, count=1
        )
        if image_count != 1 or replica_count != 1:
            raise SystemExit(f"missing or duplicate GCP overlay entry: {service}")

    content, redis_count = re.subn(
        r"(\n\s*- name: redis\n\s+count:)\s*\d+", r"\g<1> 1", content, count=1
    )
    if redis_count != 1:
        raise SystemExit("missing or duplicate redis replica entry")

    resource_marker = (
        "  # DR-ACTIVATION-RESOURCE: the approved failover workflow adds ingress.yaml here."
    )
    ingress_resource = "  - ingress.yaml"
    if ingress_resource not in content:
        if resource_marker not in content:
            raise SystemExit("missing DR ingress activation marker")
        content = content.replace(resource_marker, ingress_resource, 1)

    patch_marker = (
        "  # DR-ACTIVATION-PATCH: the approved failover workflow adds "
        "frontend-neg-patch.yaml here."
    )
    ingress_patch = "  - path: frontend-neg-patch.yaml"
    if ingress_patch not in content:
        if patch_marker not in content:
            raise SystemExit("missing DR NEG activation marker")
        content = content.replace(patch_marker, ingress_patch, 1)

    path.write_text(content, encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
