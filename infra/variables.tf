variable "region" {
  description = "リソースを作るリージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "allowed_cidr" {
  description = "API への接続を許可する IP（CIDR）。自身の環境だけに絞る（N-08）。例: 203.0.113.10/32"
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_cidr, 0)) && var.allowed_cidr != "0.0.0.0/0"
    error_message = "有効な CIDR を指定してください。0.0.0.0/0（全世界に開放）は指定できません。"
  }
}

variable "db_name" {
  description = "RDS に作る DB 名"
  type        = string
  default     = "kakeibo_production"
}

variable "db_username" {
  description = "RDS のマスターユーザー名"
  type        = string
  default     = "kakeibo"
}

variable "db_password" {
  description = "RDS のマスターパスワード。.tfvars に置き、Git にコミットしない（N-11）"
  type        = string
  sensitive   = true

  # DATABASE_URL（mysql2://user:password@host/db）にそのまま埋め込むため、
  # URL で意味を持つ記号（@ : / ? # など）を使わせない。
  validation {
    condition     = can(regex("^[A-Za-z0-9]{16,}$", var.db_password))
    error_message = "db_password は英数字のみ 16 文字以上にしてください（DATABASE_URL に埋め込むため記号は使えません）。"
  }
}
