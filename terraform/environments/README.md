# Terraform environments

Each deployment has one directory containing:

- `backend/<stack>.hcl`: the remote-state location for that stack
- `<stack>.tfvars`: the account, project, names, CIDRs, and cross-stack state contract

`phase1` points at the already-created Phase 1 state, so repeated plans and applies converge on the same resources.

Never delete or replace the remote state to "retry" an apply. Fix the failed operation and rerun with the
same deployment directory. A state reset turns managed resources into conflicting unmanaged resources.

To create another isolated deployment, copy `phase1` to a new lowercase directory and change all of the following before running the workflow:

1. Every backend `key` or `prefix` so state can never overlap.
2. AWS/GCP safety IDs if the deployment uses different accounts or projects.
3. Globally or account-unique names, including IAM, WIF, registries, clusters, databases, secrets, and VPN resources.
4. VPC, subnet, pod, service, master, and Private Service Access CIDRs so routed networks do not overlap.
5. Remote-state bucket/key/prefix references in dependent stack tfvars.
6. GitHub Environment variables and the immutable repository IDs used by OIDC trust policies.

CI runs `scripts/validate-environment-contract.py` across every deployment directory. It rejects a copied
environment when its S3/GCS state location or an account/project-scoped unique resource name still collides
with another deployment. The apply approval environment is `infrastructure-production` for the existing
`phase1` deployment and `infrastructure-<deployment>` for newly added deployments.

Do not rename a resource in an existing environment casually: Terraform will usually plan a replacement. Review the saved plan before approving apply.

GCP WIF pool/provider IDs cannot be reused while Google retains their soft-deleted records. The `gcp-cicd`
root and state buckets are therefore bootstrap resources and are intentionally retained during the normal
ephemeral-stack destroy sequence; they keep OIDC/WIF and remote state available for same-name recreation.
If the bootstrap identity itself must be destroyed, use a newly approved ID for immediate recreation or
wait until Google permanently purges the old ID.
