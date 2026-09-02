#!/usr/bin/env python3
"""Fail CI when versioned Terraform environments can share state or unique names."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ENV_ROOT = ROOT / "terraform" / "environments"
STACKS = (
    "aws-infra",
    "aws-addons",
    "gcp-cicd",
    "gcp-dr",
    "gcp-addons",
    "dr-data",
)
UNIQUE_KEYS = {
    "cluster_name",
    "vpc_name",
    "node_group_name",
    "resource_name_prefix",
    "runtime_secret_prefix",
    "artifact_repository",
    "app_ci_service_account_id",
    "workload_identity_pool_id",
    "workload_identity_provider_id",
    "network_name",
    "subnet_name",
    "router_name",
    "nat_name",
    "node_pool_name",
    "gke_service_account_id",
    "terraform_service_account_id",
    "aws_vpc_name",
    "aws_eks_cluster_name",
    "rds_identifier",
    "gcp_network_name",
    "gcp_router_name",
    "database_secret_prefix",
    "cloudsql_instance_name",
}
ASSIGNMENT = re.compile(r'^\s*([A-Za-z0-9_]+)\s*=\s*"([^"]+)"\s*(?:#.*)?$')


def strings(path: Path) -> dict[str, list[str]]:
    values: dict[str, list[str]] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        match = ASSIGNMENT.match(line)
        if match:
            values.setdefault(match.group(1), []).append(match.group(2))
    return values


def one(values: dict[str, list[str]], key: str, path: Path) -> str:
    candidates = values.get(key, [])
    if len(candidates) != 1:
        raise ValueError(f"{path}: expected exactly one quoted {key}, got {len(candidates)}")
    return candidates[0]


def scope(stack: str, key: str, values: dict[str, list[str]], path: Path) -> str:
    if stack.startswith("aws-"):
        return f"aws:{one(values, 'aws_account_id', path)}"
    if stack.startswith("gcp-"):
        project_key = "project_id" if "project_id" in values else "approved_project_id"
        return f"gcp:{one(values, project_key, path)}"
    if key.startswith("aws_") or key in {"rds_identifier", "database_secret_prefix"}:
        return f"aws:{one(values, 'aws_account_id', path)}"
    if key.startswith("gcp_") or key == "cloudsql_instance_name":
        return f"gcp:{one(values, 'gcp_project_id', path)}"
    return (
        f"hybrid:aws:{one(values, 'aws_account_id', path)}:"
        f"gcp:{one(values, 'gcp_project_id', path)}"
    )


def main() -> int:
    errors: list[str] = []
    state_owners: dict[tuple[str, str, str], str] = {}
    name_owners: dict[tuple[str, str, str], str] = {}
    environments = sorted(path for path in ENV_ROOT.iterdir() if path.is_dir())
    if not environments:
        errors.append(f"{ENV_ROOT}: no environment directories")

    for environment in environments:
        deployment = environment.name
        if not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,30}", deployment):
            errors.append(f"{environment}: invalid deployment directory name")
            continue

        for stack in STACKS:
            backend = environment / "backend" / f"{stack}.hcl"
            tfvars = environment / f"{stack}.tfvars"
            for required in (backend, tfvars):
                if not required.is_file():
                    errors.append(f"{required}: required environment file is missing")
            if not backend.is_file() or not tfvars.is_file():
                continue

            try:
                backend_values = strings(backend)
                bucket = one(backend_values, "bucket", backend)
                state_key = (
                    one(backend_values, "key", backend)
                    if "key" in backend_values
                    else one(backend_values, "prefix", backend)
                )
                backend_kind = "s3" if "key" in backend_values else "gcs"
                state_id = (backend_kind, bucket, state_key)
                owner = state_owners.setdefault(state_id, deployment)
                if owner != deployment:
                    errors.append(
                        f"{backend}: remote state {state_id} is already owned by deployment {owner}"
                    )

                tfvar_values = strings(tfvars)
                if stack in {"aws-infra", "dr-data"} and "resource_name_prefix" not in tfvar_values:
                    errors.append(f"{tfvars}: resource_name_prefix must be explicit")
                for key in UNIQUE_KEYS.intersection(tfvar_values):
                    for value in tfvar_values[key]:
                        identity = (scope(stack, key, tfvar_values, tfvars), key, value)
                        owner = name_owners.setdefault(identity, deployment)
                        if owner != deployment:
                            errors.append(
                                f"{tfvars}: {key}={value!r} conflicts with deployment {owner} in {identity[0]}"
                            )
            except ValueError as exc:
                errors.append(str(exc))

    if errors:
        print("Terraform environment isolation validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(f"Validated {len(environments)} isolated Terraform environment(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
