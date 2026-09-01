$ErrorActionPreference = "Stop"

Write-Host "This destroys only resources managed by this repository. Existing RDS, Cloud SQL, and DMS are not included."
$confirmation = Read-Host "Type DESTROY-PHASE1 to continue"
if ($confirmation -ne "DESTROY-PHASE1") {
  throw "Cancelled"
}

terraform -chdir="$PSScriptRoot/../terraform/aws-addons" destroy -auto-approve
terraform -chdir="$PSScriptRoot/../terraform/aws-infra" destroy -auto-approve
