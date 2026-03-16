# Create OIDC provider if not present
resource "aws_iam_openid_connect_provider" "oidc" {
  url = data.aws_eks_cluster.runner.identity[0].oidc[0].issuer
  client_id_list = [
    "sts.amazonaws.com"
  ]
  thumbprint_list = [
    data.tls_certificate.oidc.certificates[0].sha1_fingerprint
  ]

  tags = {
    "Name" = "${var.prefix}-runner-oidc"
  }
}

resource "aws_iam_role" "runner_irsa" {
  name               = "${var.prefix}-runner-role"
  assume_role_policy = data.aws_iam_policy_document.runner_assume_role.json
}

resource "aws_iam_policy" "runner_policy" {
  name   = "${var.prefix}-runner-policy"
  policy = data.template_file.runner_policy.rendered
}

resource "aws_iam_role_policy_attachment" "runner_attach" {
  role       = aws_iam_role.runner_irsa.name
  policy_arn = aws_iam_policy.runner_policy.arn
}

resource "kubernetes_namespace_v1" "runner_namespace" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "runner" {
  name             = local.runner_release_name
  chart            = "${path.module}/../../../../helm"
  namespace        = var.namespace
  values           = [file("${path.module}/../../../../helm/values.yaml")]
  create_namespace = false

  set = [
    {
      name  = "image.repository"
      value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.prefix}-ec2-runner"
    },
    {
      name  = "image.tag"
      value = "latest"
    },
    {
      name  = "irsa.roleArn"
      value = aws_iam_role.runner_irsa.arn
    },
    {
      name  = "prefix"
      value = var.prefix
    },
    {
      name  = "subnetId"
      value = local.public_subnet_id
    },
    {
      name  = "securityGroupId"
      value = local.cluster_security_group_id
    }
  ]
}
