
data "aws_cloudtrail_service_account" "main" {}

# Logs will also be stored in this bucket
resource "aws_s3_bucket" "marti-logs-bucket" {
  bucket        = "marti-logs-bucket"
  acl           = "private"
  force_destroy = true
  policy        = templatefile("${path.module}/policies/policyBucket.json", { cloud_trail_service_account_arn = data.aws_cloudtrail_service_account.main.arn })

  tags = {
    Name    = "marti-logs-bucket"
    tag-key = "cloud_trail"
  }
}

# Creating a new Trail, it will save the logs in the bucket as well
resource "aws_cloudtrail" "marti-cloudtrail" {
  name                       = "marti-cloudtrail"
  s3_bucket_name             = aws_s3_bucket.marti-logs-bucket.id
  s3_key_prefix              = "logs_"
  cloud_watch_logs_group_arn = aws_cloudwatch_log_group.terraform_logs.arn
  cloud_watch_logs_role_arn  = aws_iam_role.useast-prod-CloudTrail-Role-01.arn

  tags = {
    tag-key = "cloud_trail"
  }
}
# This resource allows the cloudtrail to assume the created role below.
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    sid     = ""
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

# Role for CloudTrail to create CloudWatch log streams
resource "aws_iam_role" "useast-prod-CloudTrail-Role-01" {
  name = "useast-prod-CloudTrail-Role-01"
  # Who has the right to assume this role,in this case cloudtrail.amazonaws.com
  # In the AWS console this is listed as "Trust Relationships"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json

  tags = {
    tag-key = "cloud_trail"
  }
}

# Policy to be attached to "useast-prod-CloudTrail-Role-01" role, giving CloudWatch permissions.
resource "aws_iam_policy" "cloud_trail_policy" {
  name        = "cloud_trail_policy"
  path        = "/"
  description = "This policy grants Cloud Trail permissions to create CloudWatch log streams in log group terraform_logs"
  policy      = templatefile("${path.module}/policies/permissions.json", { log_group_arn = aws_cloudwatch_log_group.terraform_logs.arn })
}

# Attaching the policy to the "useast-prod-CloudTrail-Role-01" role.
resource "aws_iam_role_policy_attachment" "role_policy_attach" {
  role       = aws_iam_role.useast-prod-CloudTrail-Role-01.id
  policy_arn = aws_iam_policy.cloud_trail_policy.arn
}

# Creating log group in CloudWatch, log stream is going to be created in it.
resource "aws_cloudwatch_log_group" "terraform_logs" {
  name = "terraform_logs"

  tags = {
    tag-key = "cloud_trail"
  }
}




