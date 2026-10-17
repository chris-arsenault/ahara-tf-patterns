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
| [`pipeline`](modules/pipeline/) | Client-owned Standard workflow, Scheduler, delivery DLQ and shared registration | Native ASL, workers, schedule, platform context |

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

The `website` module defaults new buckets to the account-scoped
`<prefix>-frontend-<account_id>` convention. Existing deployments can pass
`bucket_name` to retain their current bucket identity. When `og_config` is
enabled, use `static_asset_path_patterns` for additional S3-backed paths that
must bypass the dynamic OpenGraph origin. A static site with many reader routes
can set `og_config.manifest_key` to a JSON file in `site_directory`; the module
keeps that object out of the HTML origin, grants the OG Lambda read access, and
restarts the Lambda when the manifest changes.

Static sites serve their built `index.html` and can include OpenGraph tags there
without enabling the dynamic renderer. Their script and stylesheet filenames are
unrestricted. Dynamic OpenGraph sites retain the single-entry convention:
`assets/index-*.js` and `assets/index-*.css` must each identify the shell's entry
asset; name dependency chunks separately.

Website edge coverage defaults to `price_class = "PriceClass_100"`, preserving
delivery from North America and Europe for existing consumers. Set
`price_class = "PriceClass_200"` to add other regions except South America and
Australia/New Zealand, or `price_class = "PriceClass_All"` for worldwide edge
coverage. Regional usage rates apply; there is no fixed fee for selecting a
broader price class. This input does not change caching or security headers.

`cognito-app` keeps confidential OAuth clients as its default. Browser-only
applications use `public_oauth_client = true` with callback URLs to get a
secretless authorization-code client for PKCE.

## Lambda Observability

`lambda` accepts its existing `binary` input or a prebuilt ZIP through
`package_file`. `runtime` and `handler` default to `provided.al2023` and
`bootstrap`, preserving existing binary callers. Python callers can set
`runtime = "python3.12"` and their module handler. `ephemeral_storage` defaults
to 512 MB and can be raised to 10,240 MB. All callers retain the shared VPC,
log group, timeout, memory, and concurrency controls.

For scheduled work, enable `pipelines_enabled` on `platform-context` and pass
its `pipelines` output to `pipeline`. Shared DynamoDB tables and status delivery
belong to ahara-infra; clients own their ASL, workers, schedules and registry
items. See the [pipeline contract](https://github.com/chris-arsenault/ahara/blob/main/docs/data-pipelines.md).

`website.data_origin` routes `/data/v1/channel.json` without caching and
`/data/*` to a separately owned S3 origin. Binary ranges remain uncompressed;
clients can publish precompressed JSON with Content-Encoding. Set
`spa_fallback = false` to preserve missing-object errors and use
`invalidation_paths` to limit frontend invalidations. The website module never
uploads or prunes objects in that separate data origin.

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
