# tfstate 用 S3 の bootstrap。
# このバケット自身の state はリモートに置けないため、ここだけローカル state で管理する。
# 本体（infra/）は、ここで作ったバケットを backend に使う。

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = "kakeibo-app"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  # バケット名は全世界で一意。アカウント ID を入れて衝突を避ける。
  bucket_name = "kakeibo-tfstate-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "tfstate" {
  bucket = local.bucket_name
}

# 誤った上書き・削除から戻せるようにする。
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# state には RDS パスワードなどの機密値が入るため、公開経路を全て塞ぐ。
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
