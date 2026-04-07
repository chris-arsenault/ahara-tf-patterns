# ahara-tf-patterns

Reusable Terraform modules for the Ahara platform ecosystem.

## Architecture

This repo contains five modules under `modules/`:

- **platform-context** — Data-only module that discovers shared platform resources via tag-based lookups (VPC, ALB, subnets, security groups, Route53) and SSM parameters (Cognito, RDS). Used internally by all other modules and directly by projects needing raw platform references.

- **lambda** — Creates a single standardized Lambda function. Hardcoded: `provided.al2023` runtime, `bootstrap` handler, `x86_64`, 256 MB, VPC in private subnets with platform Lambda SG, CloudWatch log group with 14-day retention. Accepts a bare binary path (zips automatically). Only `timeout` is configurable (default 30s). Set `vpn_access = true` for TrueNAS/WireGuard connectivity. Used internally by `alb-api` and directly by projects for non-ALB Lambdas.

- **alb-api** — The primary API module. Takes a `prefix` (project IAM scope), `hostname`, and a map of Lambda functions with their routes. Creates everything: Lambda functions (via `lambda` module), shared IAM role, ALB target groups, listener rules with optional `jwt-validation`, ACM certificate, DNS record. Supports multiple Lambdas per hostname and mixed auth/unauth routes.

- **website** — Deploys a site to CloudFront + S3. Takes a `prefix` (project IAM scope), `hostname`, and `site_directory`. Handles S3 bucket with public access block, CloudFront OAC, WAF Web ACL, ACM certificate, Route53 A/AAAA records, runtime config injection via `config.js`, MIME type mapping, smart cache control, and CloudFront invalidation on deploy. Optional KMS encryption. When `og_config` is set, deploys the platform OG server Lambda as a second CloudFront origin for dynamic HTML with per-route OpenGraph meta tags.

- **cognito-app** — Registers an app client with the shared Cognito user pool. Auto-selects SPA mode (no secret) or server mode (with secret, OAuth code grant) based on whether `callback_urls` is provided. Publishes client ID to SSM for cross-project discovery.

## Resource Discovery

Platform resources are discovered via tags, not SSM where possible:

| Tag | Resource |
|-----|----------|
| `vpc:role = "platform"` | VPC |
| `lb:role = "platform"` | ALB |
| `subnet:access = "private"` | Private subnets |
| `sg:role = "lambda"` + `sg:scope = "platform"` | Platform Lambda SG |
| `sg:role = "vpn-client"` + `sg:scope = "platform"` | VPN client SG (opt-in) |
| `sg:role` + `sg:scope` (others) | Various security groups |
| Route53 zone by name `ahara.io.` | DNS zone |

SSM is used only for Cognito (no tag-based data source), RDS connection details, and the OG server S3 artifact location.

## Module Composition

`alb-api` calls `platform-context` and `lambda` internally. `lambda` calls `platform-context` for VPC/SG. Projects call `alb-api` for HTTP APIs and `lambda` directly for non-HTTP functions, reusing the IAM role from `alb-api` outputs.

## Standards Enforced

All Lambdas: `provided.al2023`, `bootstrap` handler, `x86_64`, 256 MB memory, VPC placement in private subnets with platform Lambda SG, CloudWatch log group with 14-day retention. Only `timeout` is configurable. VPN access is opt-in via `vpn_access = true`, enforced by WireGuard instance ingress rules.

## Naming and IAM

Modules take an explicit `prefix` parameter (not derived from hostname). The prefix MUST match the project's registered prefix in `platform-control`, since the deployer role's IAM scopes all resources to `{prefix}-*`. The `hostname` parameter is used only for the FQDN (DNS, ACM, CloudFront alias) and never for resource naming.

## Route53 zone resolution

`website` and `alb-api` look up the Route53 zone by taking the last two labels of `hostname`. This works for both apex domains (`ahara.io` → zone `ahara.io`) and subdomains (`api.tastebase.ahara.io` → zone `ahara.io`). For delegated subzones or multi-label TLDs (`.co.uk`, etc.), pass an explicit `zone_name`.

## Multiple hostnames on one website

The `website` module accepts an optional `aliases` list. Each alias is added to the CloudFront distribution, covered by the ACM cert as a SAN, and pointed at the distribution via Route53 A/AAAA records in the appropriate zone. Aliases can span multiple Route53 zones — each hostname's zone is auto-derived independently from its last 2 labels. Existing single-hostname consumers are unaffected (default `aliases = []`, no state churn for the primary hostname's records).
