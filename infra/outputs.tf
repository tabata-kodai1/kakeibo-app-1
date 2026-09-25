output "api_ip" {
  description = "EC2 の Elastic IP。VITE_API_BASE_URL（http://<ip>:3000）に使う"
  value       = aws_eip.api.public_ip
}

output "frontend_url" {
  description = "画面の URL（S3 の静的ウェブサイト）。ALLOWED_ORIGINS に使う。HTTP のみ"
  value       = "http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}"
}

output "frontend_bucket" {
  description = "deploy.sh が aws s3 sync で同期する先のバケット名"
  value       = aws_s3_bucket.frontend.bucket
}

output "db_name" {
  description = "RDS の DB 名。DATABASE_URL に使う（deploy.sh が読む）"
  value       = aws_db_instance.main.db_name
}

output "db_username" {
  description = "RDS のマスターユーザー名。DATABASE_URL に使う（deploy.sh が読む）。パスワードは出力せず、tfvars から読む"
  value       = aws_db_instance.main.username
}

output "rds_endpoint" {
  description = "RDS のホスト名。DATABASE_URL（mysql2://user:password@<host>/<db>）に使う"
  value       = aws_db_instance.main.address
}
