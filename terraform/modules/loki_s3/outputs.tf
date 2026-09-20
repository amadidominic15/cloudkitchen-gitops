output "chunks_bucket" { 
  value = aws_s3_bucket.chunks.bucket
}
output "ruler_bucket" {
  value = aws_s3_bucket.ruler.bucket
}
output "role_arn" {
  value = aws_iam_role.loki.arn
}
