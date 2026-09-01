output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "nat_public_ip" {
  value = module.vpc.nat_public_ips[0]
}

output "github_app_ci_role_arn" {
  value = aws_iam_role.github_app_ci.arn
}

output "github_terraform_role_arn" {
  value = aws_iam_role.github_terraform.arn
}

output "load_balancer_controller_role_arn" {
  value = aws_iam_role.load_balancer_controller.arn
}

output "external_secrets_role_arn" {
  value = aws_iam_role.external_secrets.arn
}

output "ecr_repository_urls" {
  value = { for name, repository in aws_ecr_repository.service : name => repository.repository_url }
}

output "runtime_secret_arn" {
  value = aws_secretsmanager_secret.runtime.arn
}

output "jwt_secret_arn" {
  value = aws_secretsmanager_secret.jwt.arn
}
