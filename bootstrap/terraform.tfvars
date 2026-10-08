# S3 bucket configuration variables

bucket_name                   = "3tier-app-store"
s3_versioning                 = "Enabled"
s3_object_lock                = "COMPLIANCE"
s3_object_lock_retention_days = 2
s3_object_lock_enabled        = "enabled"
force_destroy                 = true
bucket_key_enabled            = true
sse_algorithm                = "AES256"