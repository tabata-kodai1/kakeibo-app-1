terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # state は bootstrap（infra/bootstrap/）で作ったバケットに置く。
  # バケット名にはアカウント ID が入り、公開リポジトリに載せたくないため、ここには書かない。
  # backend.hcl（Git 管理外）に書き、terraform init -backend-config=backend.hcl で渡す。
  backend "s3" {
    key    = "kakeibo-app/terraform.tfstate"
    region = "ap-northeast-1"

    # DynamoDB ではなく S3 ネイティブのロックファイルで排他制御する（Terraform 1.10 以降）
    use_lockfile = true
    encrypt      = true
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
