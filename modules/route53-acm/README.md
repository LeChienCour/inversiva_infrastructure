# Route 53 and ACM Certificate Module

This Terraform module creates a Route 53 hosted zone and ACM certificate with DNS validation for use with CloudFront distributions. The module is designed to support custom domains with SSL/TLS certificates for Next.js applications deployed on AWS.

## Features

- **Route 53 Hosted Zone**: Creates or uses existing hosted zone for domain management
- **ACM Certificate**: Creates SSL/TLS certificate with DNS validation (in us-east-1 for CloudFront)
- **Multiple Subdomains**: Support for multiple subdomains in a single certificate (up to 10)
- **DNS Validation**: Automatically creates Route 53 records for certificate validation
- **Domain Records**: Creates A and AAAA records pointing to CloudFront distribution for all domains
- **Health Checks**: Optional Route 53 health monitoring on primary domain
- **Cost Optimization**: Environment-specific configurations for cost control
- **Security**: Follows AWS security best practices

## Usage

### Basic Usage

```hcl
# Provider configuration for ACM certificate (must be us-east-1)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

module "route53_acm" {
  source = "./modules/route53-acm"
  
  # Required variables
  project_name = "my-nextjs-app"
  environment  = "prod"
  domain_name  = "example.com"
  
  # CloudFront integration
  cloudfront_distribution_domain_name    = module.cloudfront.distribution_domain_name
  cloudfront_distribution_hosted_zone_id = module.cloudfront.distribution_hosted_zone_id
  
  # Provider configuration
  providers = {
    aws.us_east_1 = aws.us_east_1
  }
}
```

### Advanced Usage with Single Subdomain

```hcl
module "route53_acm" {
  source = "./modules/route53-acm"
  
  project_name = "my-nextjs-app"
  environment  = "prod"
  domain_name  = "example.com"
  subdomain    = "app"  # Creates app.example.com
  
  # Use existing hosted zone
  create_hosted_zone = false
  
  # Enable IPv6 support
  enable_ipv6 = true
  
  # Enable health monitoring
  enable_health_check           = true
  health_check_path            = "/health"
  health_check_failure_threshold = 3
  
  # CloudFront integration
  cloudfront_distribution_domain_name    = module.cloudfront.distribution_domain_name
  cloudfront_distribution_hosted_zone_id = module.cloudfront.distribution_hosted_zone_id
  
  providers = {
    aws.us_east_1 = aws.us_east_1
  }
  
  tags = {
    Owner = "DevOps Team"
    Cost  = "Production"
  }
}
```

### Multiple Subdomains Usage

```hcl
module "route53_acm_multiple" {
  source = "./modules/route53-acm"
  
  project_name = "my-nextjs-app"
  environment  = "prod"
  domain_name  = "example.com"
  
  # Multiple subdomains in a single certificate
  subdomains = [
    "www",    # www.example.com
    "api",    # api.example.com
    "app",    # app.example.com
    "admin",  # admin.example.com
    "blog"    # blog.example.com
  ]
  
  # Include root domain (example.com) in certificate
  include_root_domain = true
  
  # Primary subdomain for health checks and main DNS record
  primary_subdomain = "www"
  
  # Enable IPv6 support
  enable_ipv6 = true
  
  # Health monitoring on primary domain
  enable_health_check = true
  
  # CloudFront integration
  cloudfront_distribution_domain_name    = module.cloudfront.distribution_domain_name
  cloudfront_distribution_hosted_zone_id = module.cloudfront.distribution_hosted_zone_id
  
  providers = {
    aws.us_east_1 = aws.us_east_1
  }
  
  tags = {
    Owner      = "DevOps Team"
    Subdomains = "www,api,app,admin,blog"
  }
}
```

### Integration with CloudFront Module

```hcl
# First create the Route 53 and ACM resources
module "route53_acm" {
  source = "./modules/route53-acm"
  
  project_name = "my-nextjs-app"
  environment  = "prod"
  domain_name  = "example.com"
  
  providers = {
    aws.us_east_1 = aws.us_east_1
  }
}

# Then create CloudFront distribution with the certificate
module "cloudfront" {
  source = "./modules/cloudfront"
  
  project_name            = "my-nextjs-app"
  environment            = "prod"
  s3_bucket_domain_name  = module.s3_website.bucket_domain_name
  origin_access_control_id = module.s3_website.origin_access_control_id
  
  # Use the certificate from Route 53/ACM module
  domain_name         = module.route53_acm.full_domain_name
  acm_certificate_arn = module.route53_acm.certificate_arn
  
  depends_on = [module.route53_acm]
}

# Finally, update Route 53 records to point to CloudFront
module "route53_acm_records" {
  source = "./modules/route53-acm"
  
  project_name = "my-nextjs-app"
  environment  = "prod"
  domain_name  = "example.com"
  
  # Point to CloudFront distribution
  cloudfront_distribution_domain_name    = module.cloudfront.distribution_domain_name
  cloudfront_distribution_hosted_zone_id = module.cloudfront.distribution_hosted_zone_id
  
  providers = {
    aws.us_east_1 = aws.us_east_1
  }
  
  depends_on = [module.cloudfront]
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | ~> 5.0 |
| random | ~> 3.1 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 5.0 |
| aws.us_east_1 | ~> 5.0 |
| random | ~> 3.1 |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_route53_health_check.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_health_check) | resource |
| [aws_route53_record.certificate_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.ipv6](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Name of the project, used for resource naming | `string` | n/a | yes |
| environment | Environment name (dev, staging, prod) | `string` | n/a | yes |
| domain_name | Root domain name (e.g., example.com) | `string` | n/a | yes |
| subdomain | Single subdomain prefix (e.g., 'www' for www.example.com). If null, uses root domain. Use 'subdomains' for multiple subdomains. | `string` | `null` | no |
| subdomains | List of subdomain prefixes (e.g., ['www', 'api', 'app'] for www.example.com, api.example.com, app.example.com). Cannot be used with 'subdomain'. | `list(string)` | `[]` | no |
| include_root_domain | Whether to include the root domain in the certificate when using multiple subdomains | `bool` | `true` | no |
| primary_subdomain | Primary subdomain to use for health checks and main DNS record when using multiple subdomains. If null, uses the first subdomain in the list. | `string` | `null` | no |
| create_hosted_zone | Whether to create a new Route 53 hosted zone or use an existing one | `bool` | `true` | no |
| enable_ipv6 | Enable IPv6 AAAA records for the domain | `bool` | `false` | no |
| cloudfront_distribution_domain_name | Domain name of the CloudFront distribution to point the domain to | `string` | `null` | no |
| cloudfront_distribution_hosted_zone_id | Hosted zone ID of the CloudFront distribution | `string` | `null` | no |
| enable_health_check | Enable Route 53 health check for the domain | `bool` | `false` | no |
| health_check_path | Path to check for health monitoring | `string` | `"/"` | no |
| health_check_failure_threshold | Number of consecutive failures before marking as unhealthy | `number` | `3` | no |
| health_check_request_interval | Interval between health checks in seconds (30 or 10) | `number` | `30` | no |
| cost_optimization_enabled | Enable cost optimization features based on environment | `bool` | `true` | no |
| dev_cost_optimizations | Cost optimization settings for development environments | `object` | See variables.tf | no |
| tags | Additional tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| hosted_zone_id | ID of the Route 53 hosted zone |
| hosted_zone_name_servers | Name servers for the hosted zone (only available if created by this module) |
| domain_name | The domain name configured for this module |
| full_domain_name | The primary full domain name (including subdomain if specified) |
| all_domain_names | List of all domain names included in the certificate |
| subdomain_fqdns | List of all subdomain FQDNs (excluding root domain) |
| certificate_arn | ARN of the ACM certificate |
| certificate_domain_name | Domain name of the ACM certificate |
| certificate_subject_alternative_names | Subject alternative names of the ACM certificate |
| certificate_status | Status of the ACM certificate |
| certificate_validation_records | DNS validation records for the certificate |
| domain_record_names | Map of domain names to their A record names |
| domain_record_fqdns | Map of domain names to their A record FQDNs |
| primary_domain_record_name | Name of the primary domain A record |
| primary_domain_record_fqdn | FQDN of the primary domain A record |
| health_check_id | ID of the Route 53 health check (if enabled) |
| health_check_fqdn | FQDN being monitored by the health check |
| estimated_monthly_cost | Estimated monthly cost in USD for this module's resources |
| cost_optimization_applied | Cost optimization settings that were applied |
| module_tags | Tags applied to resources created by this module |

## Multiple Subdomains Support

This module supports both single subdomain and multiple subdomains configurations:

### Single Subdomain
Use the `subdomain` variable for a single subdomain:
```hcl
subdomain = "www"  # Creates www.example.com + example.com certificate
```

### Multiple Subdomains
Use the `subdomains` variable for multiple subdomains:
```hcl
subdomains = ["www", "api", "app", "admin"]  # Creates certificate for all subdomains
include_root_domain = true                   # Also includes example.com
primary_subdomain = "www"                    # Primary domain for health checks
```

### Key Benefits of Multiple Subdomains
- **Cost Efficient**: Single certificate covers up to 10 domains
- **Simplified Management**: One certificate renewal for all domains
- **Flexible DNS**: Separate A/AAAA records for each domain
- **Health Monitoring**: Monitors primary domain health

### Limitations
- Maximum 10 domains per certificate (AWS ACM limit)
- Cannot mix `subdomain` and `subdomains` variables
- All domains must be in the same hosted zone
- Health checks only monitor the primary domain

## Important Notes

### ACM Certificate Region

The ACM certificate **must** be created in the `us-east-1` region to be used with CloudFront. This module requires an AWS provider alias configured for `us-east-1`:

```hcl
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
```

### DNS Validation

This module uses DNS validation for ACM certificates, which requires:
1. Access to modify DNS records in the Route 53 hosted zone
2. The domain's name servers must point to the Route 53 hosted zone
3. DNS propagation time (usually 5-10 minutes)

### Cost Considerations

- **Route 53 Hosted Zone**: $0.50 per hosted zone per month
- **Route 53 Queries**: $0.40 per million queries
- **ACM Certificate**: Free for use with AWS services
- **Health Checks**: $0.50 per health check per month (if enabled)

#### Cost Optimization Features

This module includes automatic cost optimization for development environments:

- **Development Environment**: Automatically disables expensive features
- **Production Environment**: Enables all features for reliability
- **Custom Control**: Override automatic optimizations with explicit variables

**Ultra Cost-Optimized Configuration** (Development):
```hcl
module "route53_acm" {
  source = "./modules/route53-acm"
  
  project_name = "my-app"
  environment  = "dev"
  domain_name  = "example.com"
  
  # Zero fixed monthly costs
  create_hosted_zone  = false  # Use existing zone
  enable_health_check = false  # No monitoring
  enable_ipv6        = false  # IPv4 only
  
  cost_optimization_enabled = true
  
  providers = {
    aws.us_east_1 = aws.us_east_1
  }
}
```

**Cost Breakdown**:
- Ultra-optimized dev: $0.00/month fixed + query costs
- Standard dev: $0.00-1.00/month depending on features
- Production: $0.50-1.00/month for full features

### Security Best Practices

- Certificates are automatically renewed by AWS
- DNS validation records are automatically managed
- Health checks use HTTPS for secure monitoring
- All resources are tagged for proper governance

## Examples

See the `examples/` directory for complete usage examples:

- `examples/basic-example.tf` - Basic domain setup
- `examples/complete-example.tf` - Full featured setup
- `examples/existing-zone-example.tf` - Using existing hosted zone
- `examples/cost-optimized-example.tf` - Development cost optimization
- `examples/ultra-cost-optimized-example.tf` - Zero fixed cost setup

## Troubleshooting

### Certificate Validation Fails

1. Verify domain name servers point to Route 53
2. Check DNS propagation: `dig TXT _validation.example.com`
3. Ensure Route 53 hosted zone is accessible
4. Wait for DNS propagation (up to 72 hours in rare cases)

### Domain Not Resolving

1. Verify A/AAAA records are created
2. Check CloudFront distribution is deployed
3. Verify domain name servers configuration
4. Test with `dig example.com` or `nslookup example.com`

### Health Check Failures

1. Verify the health check path returns HTTP 200
2. Check SSL certificate is valid and accessible
3. Ensure CloudFront distribution is healthy
4. Review health check configuration parameters

## Contributing

When contributing to this module:

1. Follow Terraform best practices
2. Update documentation for any new variables or outputs
3. Add examples for new features
4. Test with multiple environments (dev/staging/prod)
5. Ensure cost optimization considerations are documented