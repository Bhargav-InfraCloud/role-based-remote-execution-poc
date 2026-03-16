# Fetch AWS account ID
data "aws_caller_identity" "current" {}

# Fetch EKS cluster and OIDC provider details
data "aws_eks_cluster" "runner" {
  name   = var.cluster_name
  region = var.aws_region
}

data "aws_eks_cluster_auth" "runner" {
  name   = var.cluster_name
  region = var.aws_region
}

# Fetch the OIDC thumbprint (Requires the tls provider)
data "tls_certificate" "oidc" {
  url = data.aws_eks_cluster.runner.identity[0].oidc[0].issuer
}

locals {
  runner_chart_name   = "ec2-runner"
  runner_release_name = "runner"
  # Service account name = <prefix>-<release-name>-<prefix><chart-name>
  runner_sa_name = "${var.prefix}-${local.runner_release_name}-${var.prefix}-${local.runner_chart_name}"
}

# IRSA: IAM role for Service Account
data "aws_iam_policy_document" "runner_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.oidc.arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_eks_cluster.runner.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${local.runner_sa_name}"]
    }
  }
}

data "template_file" "runner_policy" {
  template = file("${path.module}/policy/app-runner-policy.json")
  vars = {
    account_id = data.aws_caller_identity.current.account_id
    prefix     = var.prefix
  }
}

# Fetch the VPC associated with the EKS cluster
data "aws_vpc" "eks_vpc" {
  id = data.aws_eks_cluster.runner.vpc_config[0].vpc_id
}

# Fetch all subnets in the EKS VPC
data "aws_subnets" "eks_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.eks_vpc.id]
  }
}

# Fetch details for all subnets
data "aws_subnet" "eks_subnet_details" {
  for_each = toset(data.aws_subnets.eks_subnets.ids)
  id       = each.value
}

# Find the first public subnet (has map_public_ip_on_launch = true)
locals {
  public_subnet_id          = [for s in data.aws_subnet.eks_subnet_details : s.id if s.map_public_ip_on_launch][0]
  cluster_security_group_id = data.aws_eks_cluster.runner.vpc_config[0].cluster_security_group_id
}

