# Terraform environments

Each deployment has one directory containing:

- `backend/<stack>.hcl`: the remote-state location for that stack
- `<stack>.tfvars`: the account, project, names, CIDRs, and cross-stack state contract

`phase1` points at the already-created Phase 1 state, so repeated plans and applies converge on the same resources.

To create another isolated deployment, copy `phase1` to a new lowercase directory and change all of the following before running the workflow:

1. Every backend `key` or `prefix` so state can never overlap.
2. AWS/GCP safety IDs if the deployment uses different accounts or projects.
3. Globally or account-unique names, including IAM, WIF, registries, clusters, databases, secrets, and VPN resources.
4. VPC, subnet, pod, service, master, and Private Service Access CIDRs so routed networks do not overlap.
5. Remote-state bucket/key/prefix references in dependent stack tfvars.

Do not rename a resource in an existing environment casually: Terraform will usually plan a replacement. Review the saved plan before approving apply.
