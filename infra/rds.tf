# RDS（MySQL 8.4）。プライベートサブネットに置き、外部からは接続できない。

resource "aws_db_subnet_group" "main" {
  name       = "kakeibo-db"
  subnet_ids = aws_subnet.private[*].id

  tags = { Name = "kakeibo-db" }
}

# ローカルの docker-compose.yml と同じ文字コード・照合順序を明示する（N-37）。
# RDS の既定値でも同じになるが、既定に頼らず設定として残す。
resource "aws_db_parameter_group" "main" {
  name   = "kakeibo-mysql84"
  family = "mysql8.4"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_0900_ai_ci"
  }

  tags = { Name = "kakeibo-mysql84" }
}

resource "aws_db_instance" "main" {
  identifier = "kakeibo-db"

  engine         = "mysql"
  engine_version = "8.4"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.main.name
  publicly_accessible    = false
  multi_az               = false

  # 自動バックアップを有効にする（N-40）。保持期間は既定値と同じ 7 日を明示する。
  backup_retention_period = 7

  # terraform destroy で確実に撤去できるようにする（手順9）。
  # 本番運用なら true にして最終スナップショットを取るところだが、学習用途の検証環境のため取らない。
  skip_final_snapshot = true
  deletion_protection = false

  tags = { Name = "kakeibo-db" }
}
