# フロント（vite build の成果物）を静的ウェブサイトとして配信する S3 バケット。

data "aws_caller_identity" "current" {}

locals {
  # バケット名は全世界で一意。アカウント ID から組み立てて、コードには直書きしない。
  frontend_bucket_name = "kakeibo-frontend-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "frontend" {
  bucket = local.frontend_bucket_name

  # terraform destroy でファイルが残っていても撤去できるようにする（N-17）。
  force_destroy = true
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }
}

# ウェブサイトエンドポイントは匿名アクセスで配信するため、ポリシーによる公開を許す。
# 代わりに、次のバケットポリシーで aws:SourceIp によって接続元を絞る（N-08）。
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

# EC2 のセキュリティグループは S3 に効かない。画面側の制限はここでかける。
# EC2 の SG と同じ allowed_cidr にすることで、API と画面の両方が同じ接続元に限定される。
data "aws_iam_policy_document" "frontend" {
  statement {
    sid       = "AllowGetFromAllowedCidrOnly"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "IpAddress"
      variable = "aws:SourceIp"
      values   = [var.allowed_cidr]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend.json

  depends_on = [aws_s3_bucket_public_access_block.frontend]
}
