# Centralized Configuration Approach

## Problem Solved

Previously, we had configuration duplicated across multiple files:
- Environment-level terragrunt.hcl had some config
- Each module's terragrunt.hcl repeated similar config
- Changes required updating multiple files

## New Approach: Single Source of Truth

All environment-specific configuration is now centralized in `environments/dev/terragrunt.hcl`.

### Configuration Structure

```hcl
locals {
  dev_config = {
    # === COGNITO CONFIGURATION ===
    cognito = {
      password_policy = { ... }
      mfa_configuration = "OPTIONAL"
      callback_urls = [ ... ]
      # ... all cognito settings
    }
    
    # === S3 CONFIGURATION ===
    s3 = {
      enable_versioning = false
      lifecycle_transition_ia_days = 7
      # ... all s3 settings
    }
    
    # === CLOUDFRONT CONFIGURATION ===
    cloudfront = {
      price_class = "PriceClass_100"
      enable_ipv6 = false
      # ... all cloudfront settings
    }
    
    # === SHARED CORS CONFIGURATION ===
    cors = {
      allow_origins = [
        "http://localhost:3000",
        "https://dev.placeholder.mx"
      ]
      # ... shared across all services
    }
  }
}
```

### Module Configuration (Clean & Simple)

Each module now just references the centralized config:

```hcl
# cognito/terragrunt.hcl
inputs = {
  password_policy = local.dev_config.cognito.password_policy
  mfa_configuration = local.dev_config.cognito.mfa_configuration
  callback_urls = local.dev_config.cognito.callback_urls
  # ... etc
}
```

## Benefits

### ✅ **Single Source of Truth**
- All dev environment config in one file
- Change CORS origins once, applies everywhere
- Change domain once, applies everywhere

### ✅ **No Duplication**
- CORS settings defined once, used by CloudFront, S3, Cognito
- Domain settings defined once, used by all modules
- Cost optimization flags defined once

### ✅ **Easy Environment Comparison**
- Want to see differences between dev and prod?
- Just compare the two environment terragrunt.hcl files

### ✅ **Easier Maintenance**
- Need to add a new CORS origin? Change it in one place
- Need to update token validity? Change it in one place
- Need to enable monitoring? Change one flag

### ✅ **Clear Dependencies**
- Modules still have proper dependencies
- But configuration comes from environment
- Dependencies handle resource ARNs and outputs

## Example: Adding a New Environment

To create a staging environment:

1. **Copy** `environments/dev/` to `environments/staging/`
2. **Update** only `environments/staging/terragrunt.hcl`:
   ```hcl
   locals {
     environment = "staging"
     domain_name = "staging.placeholder.mx"
     
     dev_config = {
       cognito = {
         mfa_configuration = "ON"  # More strict for staging
         # ... other staging-specific changes
       }
       # ... rest stays the same or gets staging-specific values
     }
   }
   ```
3. **Done!** All modules automatically get staging config

## File Structure

```
environments/dev/
├── terragrunt.hcl              # 🎯 ALL CONFIG HERE
├── cognito/
│   └── terragrunt.hcl         # Just references local.dev_config.cognito.*
├── s3-content/
│   └── terragrunt.hcl         # Just references local.dev_config.s3.*
├── cloudfront/
│   └── terragrunt.hcl         # Just references local.dev_config.cloudfront.*
└── ...
```

## Migration Benefits

- **Before**: 50+ lines of config per module = 250+ lines total
- **After**: ~10 lines per module + centralized config = Much cleaner
- **Before**: Change CORS = update 3 files
- **After**: Change CORS = update 1 line

This approach follows the DRY principle while maintaining Terragrunt's dependency management and modular structure.