variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

# Variables for the S3 bucket configuration
# This variable defines the name of the S3 bucket to be created.
# This variable is used to set the name of the S3 bucket in the main.tf file.
# the type of this variable is string. which means it expects a sequence of characters as its value.
# For example, if you set this variable to "my-bucket", the S3 bucket will be named "my-bucket".
variable "bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
}

# Variables for the S3 bucket versioning and object lock configuration
# The following variables control the versioning and object lock settings for the S3 bucket.
# The default value for the S3 bucket versioning is "Enabled".
variable "s3_versioning" {
  description = "Enable or disable versioning for the S3 bucket"
  type        = string
  default     = "Enabled"
}

# Variables for the S3 bucket object lock retention configuration
# The following variable controls the retention period for objects in the S3 bucket when object lock is enabled.    
# The default value for the S3 bucket object lock is "Compliance".
variable "s3_object_lock" {
  description = "Enable or disable object lock for the S3 bucket"
  type        = string
  default     = "Compliance"
}

# Variables for the S3 bucket object lock retention period configuration
# The following variable controls the number of days to retain objects in the S3 bucket when object lock is enabled.
# The default value for the S3 bucket object lock retention period is 2 days.
variable "s3_object_lock_retention_days" {
  description = "The number of days to retain objects in the S3 bucket when object lock is enabled"
  type        = number
  default     = 2
}

variable "s3_object_lock_enabled" {
  description = "Enable or disable object lock for the S3 bucket"
  type        = string
  default     = "enabled"
}

variable "force_destroy" {
  description = "Force destroy the S3 bucket even if it contains objects"
  type        = bool
}
variable "s3_server_side_encryption" {
  description = "Enable or disable server-side encryption for the S3 bucket"
  type        = string
  default     = "AES256"
}

variable "kms_master_key_id" {
  description = "The KMS master key ID to use for server-side encryption of the S3 bucket"
  type        = string
  default     = ""
}

variable "bucket_key_enabled" {
  description = "Enable or disable bucket key for server-side encryption of the S3 bucket"
  type        = bool
  default     = true
}

variable "sse_algorithm" {
  description = "The server-side encryption algorithm to use for the S3 bucket"
  type        = string
  default     = "AES256"
}
