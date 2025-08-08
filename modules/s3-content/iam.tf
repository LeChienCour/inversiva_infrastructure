# IAM policies for Cognito-based S3 content access

# IAM role for authenticated Cognito users
resource "aws_iam_role" "cognito_authenticated_role" {
  name_prefix = "${var.bucket_name_prefix}-cognito-auth-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = var.cognito_user_pool_arn
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.bucket_name_prefix}-cognito-authenticated-role"
    Environment = var.environment
    Purpose     = "Cognito User S3 Access"
    Module      = "s3-content"
  })
}

# IAM policy for user-specific S3 access based on Cognito identity
data "aws_iam_policy_document" "cognito_user_policy" {
  statement {
    sid    = "AllowUserSpecificObjectAccess"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = [
      "${aws_s3_bucket.content_bucket.arn}/users/$${cognito-identity.amazonaws.com:sub}/*"
    ]
  }

  statement {
    sid    = "AllowUserSpecificListAccess"
    effect = "Allow"

    actions = [
      "s3:ListBucket"
    ]

    resources = [
      aws_s3_bucket.content_bucket.arn
    ]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["users/$${cognito-identity.amazonaws.com:sub}/*"]
    }
  }
}

# Attach the policy to the Cognito authenticated role
resource "aws_iam_role_policy" "cognito_user_s3_policy" {
  name_prefix = "${var.bucket_name_prefix}-cognito-s3-"
  role        = aws_iam_role.cognito_authenticated_role.id
  policy      = data.aws_iam_policy_document.cognito_user_policy.json
}

# IAM policy for admin operations (full bucket access)
data "aws_iam_policy_document" "admin_policy" {
  statement {
    sid    = "AllowAdminFullAccess"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObjectVersion",
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]

    resources = [
      aws_s3_bucket.content_bucket.arn,
      "${aws_s3_bucket.content_bucket.arn}/*"
    ]
  }
}

# IAM policy resource for admin access
resource "aws_iam_policy" "admin_policy" {
  name_prefix = "${var.bucket_name_prefix}-admin-"
  description = "Admin policy for full S3 content bucket access"
  policy      = data.aws_iam_policy_document.admin_policy.json

  tags = merge(var.tags, {
    Name        = "${var.bucket_name_prefix}-admin-policy"
    Environment = var.environment
    Purpose     = "Admin S3 Access"
    Module      = "s3-content"
  })
}

