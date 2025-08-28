# Cognito User Pool
resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-${var.environment}-user-pool"

  # Password policy configuration
  password_policy {
    minimum_length                   = var.password_policy.minimum_length
    require_lowercase                = var.password_policy.require_lowercase
    require_numbers                  = var.password_policy.require_numbers
    require_symbols                  = var.password_policy.require_symbols
    require_uppercase                = var.password_policy.require_uppercase
    temporary_password_validity_days = var.password_policy.temporary_password_validity_days
  }

  # MFA configuration based on environment
  mfa_configuration = var.mfa_configuration

  # Software token MFA configuration (TOTP)
  dynamic "software_token_mfa_configuration" {
    for_each = var.mfa_configuration != "OFF" && var.enable_software_token_mfa ? [1] : []
    content {
      enabled = true
    }
  }

  # Account recovery settings
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # User pool add-ons
  user_pool_add_ons {
    advanced_security_mode = var.environment == "prod" ? "ENFORCED" : "OFF"
  }

  # Email configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # Username configuration
  username_attributes = ["email"]

  # Auto-verified attributes
  auto_verified_attributes = ["email"]

  # User attributes
  schema {
    attribute_data_type = "String"
    name                = "email"
    required            = true
    mutable             = true
  }

  schema {
    attribute_data_type = "String"
    name                = "name"
    required            = true
    mutable             = true
  }

  # Deletion protection for production
  deletion_protection = var.environment == "prod" ? "ACTIVE" : "INACTIVE"

  tags = var.tags
}

# Cognito User Pool Client
resource "aws_cognito_user_pool_client" "main" {
  name         = "${var.project_name}-${var.environment}-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # OAuth2/OIDC configuration
  generate_secret              = false
  explicit_auth_flows          = var.explicit_auth_flows
  supported_identity_providers = ["COGNITO"]

  # OAuth configuration
  allowed_oauth_flows                  = var.allowed_oauth_flows
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = var.allowed_oauth_scopes

  # Callback and logout URLs
  callback_urls = var.callback_urls
  logout_urls   = var.logout_urls

  # Token validity
  access_token_validity  = var.token_validity.access_token
  id_token_validity      = var.token_validity.id_token
  refresh_token_validity = var.token_validity.refresh_token

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # Prevent user existence errors
  prevent_user_existence_errors = "ENABLED"

  depends_on = [aws_cognito_user_pool.main]
}

# Cognito Identity Pool
resource "aws_cognito_identity_pool" "main" {
  identity_pool_name               = "${var.project_name}-${var.environment}-identity-pool"
  allow_unauthenticated_identities = var.allow_unauthenticated_identities

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.main.id
    provider_name           = aws_cognito_user_pool.main.endpoint
    server_side_token_check = true
  }

  tags = var.tags
}

# IAM role for authenticated users
resource "aws_iam_role" "authenticated" {
  name = "${var.project_name}-${var.environment}-cognito-authenticated-role"

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
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.main.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# IAM policy for authenticated users
resource "aws_iam_role_policy" "authenticated" {
  name = "${var.project_name}-${var.environment}-cognito-authenticated-policy"
  role = aws_iam_role.authenticated.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = var.content_bucket_arn != "" ? "${var.content_bucket_arn}/*" : "*"
        Condition = {
          StringLike = {
            "s3:ExistingObjectTag/user-id" = "$${cognito-identity.amazonaws.com:sub}"
          }
        }
      }
    ]
  })
}

# IAM role for unauthenticated users (if enabled)
resource "aws_iam_role" "unauthenticated" {
  count = var.allow_unauthenticated_identities ? 1 : 0
  name  = "${var.project_name}-${var.environment}-cognito-unauthenticated-role"

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
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.main.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "unauthenticated"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# Attach roles to identity pool
resource "aws_cognito_identity_pool_roles_attachment" "main" {
  identity_pool_id = aws_cognito_identity_pool.main.id

  roles = merge(
    {
      "authenticated" = aws_iam_role.authenticated.arn
    },
    var.allow_unauthenticated_identities ? {
      "unauthenticated" = aws_iam_role.unauthenticated[0].arn
    } : {}
  )

  depends_on = [
    aws_cognito_identity_pool.main,
    aws_iam_role.authenticated,
    aws_iam_role.unauthenticated
  ]
}