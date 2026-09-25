output "bucket_name" {
  description = "本体の backend \"s3\" に指定するバケット名"
  value       = aws_s3_bucket.tfstate.bucket
}
