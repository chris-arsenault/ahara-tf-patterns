# ahara-tf-patterns

Reusable Terraform modules for the Ahara platform ecosystem.

## Architecture

This repo contains six modules under `modules/`:

- **platform-context** — Data-only module that discovers shared platform resources via tag-based lookups (VPC, ALB, subnets, security groups, Route53) and SSM parameters (Cognito, RDS). Used internally by `alb-api` and `cognito-app`, and directly by projects needing raw platform references.

- **lambda** — Creates a single standardized Lambda function. Hardcoded: `provided.al2023` runtime, `bootstrap` handler, `x86_64`, 256 MB, 30s timeout. Creates a CloudWatch log group with 14-day retention. Used internally by `alb-api` and directly by projects for non-ALB lambdas (async processors, triggers).

- **alb-api** — The primary API module. Takes a hostname and a map of Lambda functions with their routes. Creates everything: Lambda functions (via `lambda` module), shared IAM role, security group, ALB target groups, listener rules with optional `jwt-validation`, ACM certificate, DNS record. Supports multiple lambdas per hostname and mixed auth/unauth routes.

- **spa-website** — Deploys a single-page app to CloudFront + S3. Handles S3 bucket with public access block, CloudFront OAC, WAF Web ACL, ACM certificate, Route53 A/AAAA records, runtime config injection via `config.js`, MIME type mapping, smart cache control (no-cache for index.html, immutable for hashed assets), and CloudFront invalidation on deploy. Optional KMS encryption.

- **static-website** — Like `spa-website` but for static sites: S3 versioning, uniform 1-hour cache TTL, no SPA error fallback (404/403 are real errors), no WAF or KMS.

- **cognito-app** — Registers an app client with the shared Cognito user pool. Auto-selects SPA mode (no secret) or server mode (with secret, OAuth code grant) based on whether `callback_urls` is provided. Publishes client ID to SSM for cross-project discovery.

## Resource Discovery

Platform resources are discovered via tags, not SSM where possible:

| Tag | Resource |
|-----|----------|
| `vpc:role = "platform"` | VPC |
| `lb:role = "platform"` | ALB |
| `subnet:access = "private"` | Private subnets |
| `sg:role` + `sg:scope` | Security groups |
| Route53 zone by name `ahara.io.` | DNS zone |

SSM is used only for Cognito (no tag-based data source) and RDS connection details.

## Module Composition

`alb-api` calls `platform-context` and `lambda` internally. Projects call `alb-api` for HTTP APIs and `lambda` directly for non-HTTP functions, reusing the IAM role and security group from `alb-api` outputs.

## Standards Enforced

All Lambda modules enforce: `provided.al2023`, `bootstrap` handler, `x86_64`, 256 MB memory, 30s timeout, VPC placement in private subnets, CloudWatch log group with 14-day retention.
