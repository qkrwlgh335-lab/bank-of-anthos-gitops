data "aws_iam_policy_document" "irsa_trust" {
  for_each = {
    load_balancer_controller = "system:serviceaccount:kube-system:aws-load-balancer-controller"
    external_secrets         = "system:serviceaccount:external-secrets:external-secrets"
  }

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = [each.value]
    }
  }
}

resource "aws_iam_role" "load_balancer_controller" {
  name               = "${var.resource_name_prefix}-eks-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.irsa_trust["load_balancer_controller"].json
}

resource "aws_iam_policy" "load_balancer_controller" {
  name   = "${var.resource_name_prefix}-eks-load-balancer-controller"
  policy = file("${path.module}/policies/aws-load-balancer-controller.json")
}

resource "aws_iam_role_policy_attachment" "load_balancer_controller" {
  role       = aws_iam_role.load_balancer_controller.name
  policy_arn = aws_iam_policy.load_balancer_controller.arn
}

resource "aws_iam_role" "external_secrets" {
  name               = "${var.resource_name_prefix}-eks-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.irsa_trust["external_secrets"].json
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      aws_secretsmanager_secret.runtime.arn,
      aws_secretsmanager_secret.jwt.arn,
    ]
  }
}

resource "aws_iam_role_policy" "external_secrets" {
  name   = "read-bank-runtime-secrets"
  role   = aws_iam_role.external_secrets.id
  policy = data.aws_iam_policy_document.external_secrets.json
}
