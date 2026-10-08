# ===============================================================
# REMOTE STATE BACKEND (S3)
# Stores terraform.tfstate in S3 instead of on this laptop.
#
# The bucket name and region are NOT here on purpose. They differ
# per environment/account, so they live in backend.hcl, which is
# NOT committed to Git. This is called "partial configuration".
# ===============================================================
terraform {
  backend "s3" {
    # Where inside the bucket the state file is stored
    key = "job-readiness/project-1/terraform.tfstate"

    # Encrypt the state file in S3
    encrypt = true

    # Native S3 locking: while someone runs plan or apply, Terraform
    # creates terraform.tfstate.tflock next to the state file.
    # Anyone else who tries to run at the same time gets blocked.
    # This replaces the old DynamoDB lock table.
    use_lockfile = true
  }
}