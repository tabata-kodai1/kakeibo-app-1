output "rds_endpoint" {
  description = "RDS のホスト名。DATABASE_URL（mysql2://user:password@<host>/<db>）に使う"
  value       = aws_db_instance.main.address
}
