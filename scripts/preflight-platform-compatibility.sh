#!/usr/bin/env bash
set -Eeuo pipefail

[[ $# -eq 2 ]] || { echo "usage: $0 <stack> <tfvars>" >&2; exit 2; }
stack="$1"
tfvars="$2"
[[ -f "$tfvars" ]] || { echo "Missing tfvars: $tfvars" >&2; exit 1; }

tf_string() {
  local key="$1"
  sed -nE "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"([^\"]+)\".*/\1/p" "$tfvars" | head -n 1
}

require_value() {
  local key="$1" value
  value=$(tf_string "$key")
  [[ -n "$value" ]] || { echo "$tfvars: missing quoted $key" >&2; exit 1; }
  printf '%s' "$value"
}

check_aws_eks() {
  local region version cluster supported cluster_count cluster_quota existing
  region=$(require_value aws_region)
  version=$(require_value kubernetes_version)
  cluster=$(require_value cluster_name)
  supported=$(aws eks describe-cluster-versions --region "$region" \
    --cluster-versions "$version" \
    --query 'clusterVersions[?status==`STANDARD_SUPPORT` || status==`EXTENDED_SUPPORT`].clusterVersion | [0]' \
    --output text 2>/dev/null || true)
  [[ "$supported" == "$version" ]] || {
    echo "EKS Kubernetes $version is not creatable in $region or is outside supported status" >&2
    exit 1
  }

  existing=$(aws eks describe-cluster --region "$region" --name "$cluster" \
    --query 'cluster.name' --output text 2>/dev/null || true)
  if [[ "$existing" != "$cluster" ]]; then
    cluster_count=$(aws eks list-clusters --region "$region" --query 'length(clusters)' --output text)
    cluster_quota=$(aws service-quotas list-service-quotas --region "$region" --service-code eks \
      --query "Quotas[?QuotaName=='Clusters'].Value | [0]" --output text 2>/dev/null || true)
    if [[ "$cluster_quota" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      awk -v used="$cluster_count" -v quota="$cluster_quota" \
        'BEGIN { if (used >= quota) { printf "EKS cluster quota exhausted: used=%s quota=%s\n", used, quota > "/dev/stderr"; exit 1 } }'
    else
      echo "Warning: EKS cluster quota could not be read; Terraform plan remains authoritative"
    fi
  fi
  echo "EKS preflight OK: version=$version region=$region"
}

check_rds_postgres() {
  local region version identifier supported existing db_count db_quota
  region=$(require_value aws_region)
  version=$(require_value rds_engine_version)
  identifier=$(require_value rds_identifier)
  supported=$(aws rds describe-db-engine-versions --region "$region" --engine postgres \
    --engine-version "$version" --query 'DBEngineVersions[0].EngineVersion' --output text 2>/dev/null || true)
  [[ "$supported" == "$version" ]] || {
    echo "RDS PostgreSQL $version is not available in $region" >&2
    exit 1
  }
  existing=$(aws rds describe-db-instances --region "$region" --db-instance-identifier "$identifier" \
    --query 'DBInstances[0].DBInstanceIdentifier' --output text 2>/dev/null || true)
  if [[ "$existing" != "$identifier" ]]; then
    db_count=$(aws rds describe-db-instances --region "$region" --query 'length(DBInstances)' --output text)
    db_quota=$(aws service-quotas list-service-quotas --region "$region" --service-code rds \
      --query "Quotas[?QuotaName=='DB instances'].Value | [0]" --output text 2>/dev/null || true)
    if [[ "$db_quota" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      awk -v used="$db_count" -v quota="$db_quota" \
        'BEGIN { if (used >= quota) { printf "RDS DB instance quota exhausted: used=%s quota=%s\n", used, quota > "/dev/stderr"; exit 1 } }'
    else
      echo "Warning: RDS instance quota could not be read; Terraform plan remains authoritative"
    fi
  fi
  echo "RDS preflight OK: PostgreSQL=$version region=$region"
}

check_gke_channel() {
  local project region enabled valid
  project=$(require_value project_id)
  region=$(require_value region)
  if ! enabled=$(gcloud services list --enabled --project "$project" \
    --filter='config.name:container.googleapis.com' --format='value(config.name)'); then
    echo "Cannot inspect GCP services for $project; verify WIF identity and serviceusage.services.list" >&2
    exit 1
  fi
  if [[ "$enabled" != "container.googleapis.com" ]]; then
    echo "GKE preflight deferred: container.googleapis.com is not enabled yet; this stack enables it"
    return
  fi
  valid=$(gcloud container get-server-config --project "$project" --region "$region" --format=json \
    | jq '[.channels[] | select(.channel == "REGULAR") | .validVersions[]] | length')
  [[ "$valid" -gt 0 ]] || { echo "GKE REGULAR channel has no creatable version in $region" >&2; exit 1; }
  echo "GKE preflight OK: REGULAR channel has $valid valid version(s) in $region"
}

check_cloud_sql() {
  local project region tier enabled available
  project=$(require_value gcp_project_id)
  region=$(require_value gcp_region)
  tier=$(require_value cloudsql_tier)
  if ! enabled=$(gcloud services list --enabled --project "$project" \
    --filter='config.name:sqladmin.googleapis.com' --format='value(config.name)'); then
    echo "Cannot inspect GCP services for $project; verify WIF identity and serviceusage.services.list" >&2
    exit 1
  fi
  if [[ "$enabled" != "sqladmin.googleapis.com" ]]; then
    echo "Cloud SQL preflight deferred: sqladmin.googleapis.com is not enabled yet; Terraform enables it"
    return
  fi
  available=$(gcloud sql tiers list --project "$project" \
    --filter="tier:${tier} AND region:${region}" --format='value(tier)' | head -n 1)
  [[ "$available" == "$tier" ]] || { echo "Cloud SQL tier $tier is not available in $region" >&2; exit 1; }
  echo "Cloud SQL preflight OK: PostgreSQL 16 configuration tier=$tier region=$region"
}

case "$stack" in
  aws-infra) check_aws_eks ;;
  gcp-dr) check_gke_channel ;;
  dr-data)
    check_rds_postgres
    check_cloud_sql
    ;;
  *) echo "No platform-version preflight is required for $stack" ;;
esac
