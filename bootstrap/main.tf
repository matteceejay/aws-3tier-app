resource "aws_s3_bucket" "aws3tier-app" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_public_access_block" "bck-access" {
  bucket                  = aws_s3_bucket.aws3tier-app.bucket
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "s3-version" {
  bucket = aws_s3_bucket.aws3tier-app.bucket
  versioning_configuration {
    status = var.s3_versioning
  }
}

resource "aws_s3_bucket_object_lock_configuration" "object-lock" {
  bucket              = aws_s3_bucket.aws3tier-app.bucket
  object_lock_enabled = "Enabled"
  rule {
    default_retention {
      mode = var.s3_object_lock
      days = var.s3_object_lock_retention_days
    }
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "s3-encrypt" {
  bucket = aws_s3_bucket.aws3tier-app.bucket
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm      = var.sse_algorithm
      }
    }
  }
resource "aws_kms_key" "s3-kms-key" {
  description              = "KMS key for S3 bucket encryption"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
}
 