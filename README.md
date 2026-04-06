# ahara-tf-patterns

Reusable Terraform modules for the Ahara platform. These modules encode standard patterns for deploying applications on the shared infrastructure (ALB, Cognito, CloudFront, VPC).

## Modules

| Module | Purpose | Required Params |
|--------|---------|-----------------|
| [`platform-context`](modules/platform-context/) | Reads shared platform resources (VPC, ALB, Cognito, RDS) via tag-based lookups and SSM | 0 |
| [`lambda`](modules/lambda/) | Standardized Lambda function with CloudWatch log group | 3 |
| [`alb-api`](modules/alb-api/) | Lambda API(s) behind the shared ALB with JWT auth and custom domain | 2 |
| [`website`](modules/website/) | Site on CloudFront + S3 with custom domain, WAF, KMS, optional OG server | 2 |
| [`cognito-app`](modules/cognito-app/) | Register an app client with the shared Cognito pool | 1 |

## Usage

Source modules via git:

```hcl
module "api" {
  source   = "git::https://github.com/chris-arsenault/ahara-tf-patterns.git//modules/alb-api"
  hostname = "api.myapp.ahara.io"

  lambdas = {
    api = {
      binary = "../../backend/target/lambda/api/bootstrap"
      routes = [{ priority = 201, paths = ["/api/*"], authenticated = true }]
    }
  }
}
```

## Requirements

- Terraform >= 1.12
- AWS provider >= 6.0
- Deployed platform infrastructure (platform-network, platform-services)

## Documentation

See [INTEGRATION.md](https://github.com/chris-arsenault/platform/blob/main/INTEGRATION.md) for full platform integration instructions.
