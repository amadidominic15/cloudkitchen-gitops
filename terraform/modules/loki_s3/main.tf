resource "aws_s3_bucket" "chunks" {
  bucket = var.chunks_bucket
  tags = { Environment = var.environment 
  ManagedBy = "Terraform"
  Purpose = "Loki" 
  }
}
resource "aws_s3_bucket" "ruler" {
  bucket = var.ruler_bucket
  tags = { Environment = var.environment
  ManagedBy = "Terraform"
  Purpose = "Loki" 
  }
}
resource "aws_s3_bucket_versioning" "chunks" { 
  bucket = aws_s3_bucket.chunks.id
  versioning_configuration { 
    status = "Enabled" 
    } 
}
resource "aws_s3_bucket_versioning" "ruler" { 
  bucket = aws_s3_bucket.ruler.id
  versioning_configuration { 
    status = "Enabled" 
    } 
}
resource "aws_s3_bucket_server_side_encryption_configuration" "chunks" {
  bucket = aws_s3_bucket.chunks.id
  rule { 
    apply_server_side_encryption_by_default { 
      sse_algorithm = "AES256" 
    } 
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "ruler" {
  bucket = aws_s3_bucket.ruler.id
  rule { 
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" 
    } 
  }
}
resource "aws_s3_bucket_public_access_block" "chunks" {
  bucket = aws_s3_bucket.chunks.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_public_access_block" "ruler" {
  bucket = aws_s3_bucket.ruler.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}
data "aws_iam_policy_document" "loki" {
  statement { 
    effect = "Allow"
    actions = ["s3:ListBucket"]
    resources = [aws_s3_bucket.chunks.arn, aws_s3_bucket.ruler.arn] 
  }
  statement { 
    effect = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.chunks.arn}/*", "${aws_s3_bucket.ruler.arn}/*"] 
  }
}

resource "aws_iam_policy" "loki" { 
  name = "${var.cluster_name}-loki-s3"
  policy = data.aws_iam_policy_document.loki.json 
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition { 
      test = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:aud"
      values = ["sts.amazonaws.com"] 
       }
    condition { 
      test = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values = ["system:serviceaccount:loki:loki"] 
    }
  }
}

resource "aws_iam_role" "loki" { 
  name = "${var.cluster_name}-loki"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json 
}

resource "aws_iam_role_policy_attachment" "loki" { 
  role = aws_iam_role.loki.name
  policy_arn = aws_iam_policy.loki.arn 
}

resource "kubernetes_namespace_v1" "loki" { 
  metadata { name = "loki" } 
}
resource "kubernetes_service_account_v1" "loki" {
  metadata {
    name = "loki"
    namespace = "loki"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.loki.arn
    }
    labels = { "app.kubernetes.io/name" = "loki" }
  }
  depends_on = [aws_iam_role_policy_attachment.loki]
}

