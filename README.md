# ahara-tf-patterns

Reusable Terraform modules for the Ahara platform. These modules encode standard patterns for deploying applications on the shared infrastructure (ALB, Cognito, CloudFront, VPC).

## Modules

| Module | Purpose | Required Params |
|--------|---------|-----------------|
| [`platform-context`](modules/platform-context/) | Reads shared platform resources (VPC, ALB, Cognito, RDS) via tag-based lookups and SSM | 0 |
| [`lambda`](modules/lambda/) | Standardized Lambda function with CloudWatch log group | 3 |
| [`alb-api`](modules/alb-api/) | Lambda API(s) behind the shared ALB with JWT auth and custom domain | 3 |
| [`website`](modules/website/) | Site on CloudFront + account-scoped S3 with custom domain, KMS, optional OG server | 3 |
| [`cognito-app`](modules/cognito-app/) | Register an app client with the shared Cognito pool | 1 |

## Usage

Source modules via git:

```hcl
module "api" {
  source   = "git::https://github.com/chris-arsenault/ahara-tf-patterns.git//modules/alb-api"
  prefix   = "myapp"
  hostname = "api.myapp.ahara.io"

  lambdas = {
    api = {
      binary = "../../backend/target/lambda/api/bootstrap"
      routes = [{ priority = 201, paths = ["/api/*"], authenticated = true }]
    }
  }
}
```

`prefix` must match the project prefix registered with ahara-control — all resource names use it so they fall within the deployer role's IAM scope.

## Lambda Observability

The `lambda` module and `alb-api` Lambda entries expose the standard observability hooks used by Ahara services:

- `tracing_mode = "Active"` enables AWS X-Ray tracing for the Lambda.
- `layers = [...]` attaches ADOT or vendor OpenTelemetry collector layers.
- OTLP exporters are configured with normal `OTEL_*` environment variables in the module `environment` maps.
- `managed_policy_arns = [...]` on `alb-api` attaches shared role policies such as AWS Application Signals execution access.

Do not fork the module to add one-off collector/runtime wiring; add reusable module inputs here instead.

## Requirements

- Terraform >= 1.12
- AWS provider >= 6.0
- Deployed platform infrastructure (ahara-network, ahara-services)
- Deployer role configured in [ahara-control](https://github.com/chris-arsenault/ahara-control) with the appropriate `module_bundles` (one per shared module you use)

## Documentation

See [INTEGRATION.md](https://github.com/chris-arsenault/ahara/blob/main/INTEGRATION.md) for full platform integration instructions.
