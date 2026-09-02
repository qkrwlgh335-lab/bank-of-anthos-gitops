$ErrorActionPreference = "Stop"

throw @"
Direct local destroy is disabled because it bypasses the reviewed saved-plan
approval path. Run the GitHub workflow 'Terraform plan and apply' with
action=destroy for one stack at a time.

Ephemeral stack order:
  1. gcp-addons
  2. aws-addons
  3. dr-data
  4. gcp-dr
  5. aws-infra

Keep gcp-cicd and the remote-state buckets as bootstrap resources. They own the
OIDC/WIF identity needed to run the workflow and remain managed in their remote
state, so they do not become unmanaged name conflicts.
"@
