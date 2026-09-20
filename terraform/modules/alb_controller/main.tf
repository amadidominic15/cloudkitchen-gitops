data "aws_caller_identity" "current" {}

data "http" "lbc_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v3.3.0/docs/install/iam_policy.json"
}

locals {
  oidc_provider = replace(
    var.oidc_issuer_url,
    "https://",
    ""
  )
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name = "${var.cluster_name}-AWSLoadBalancerController"

  policy = data.http.lbc_iam_policy.response_body
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "${var.cluster_name}-aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Federated = var.oidc_provider_arn
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "${local.oidc_provider}:aud" = "sts.amazonaws.com"

            "${local.oidc_provider}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })

  tags = {
    Terraform = "true"
  }
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role = aws_iam_role.aws_load_balancer_controller.name

  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

resource "helm_release" "aws_load_balancer_controller" {
  name = "aws-load-balancer-controller"

  repository = "https://aws.github.io/eks-charts"

  chart = "aws-load-balancer-controller"

  namespace = "kube-system"

  version = "1.17.0"

  wait = true

  timeout = 900

  values = [
    yamlencode({
      clusterName = var.cluster_name

      region = var.aws_region

      serviceAccount = {
        create = true

        name = "aws-load-balancer-controller"

        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller.arn
        }
      }

      replicaCount = 2
    })
  ]

  depends_on = [
    aws_iam_role_policy_attachment.aws_load_balancer_controller
  ]
}