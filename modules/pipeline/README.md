# Pipeline

Creates client-owned Step Functions Standard and EventBridge Scheduler resources,
scoped roles, a delivery DLQ, and the client's registration in Ahara's shared
DynamoDB registry. Supply native ASL and worker ARNs. This module does not create
workers, process data, or publish datasets. Schedules default to disabled.

Set `pipelines_enabled = true` on platform-context and pass its `pipelines`
output as `platform`. Declare the `pipeline` bundle
in the project's Ahara control registration. The module's resources belong to
the calling project's Terraform state; shared job summaries belong to Ahara.

Use the Step Functions console or `aws stepfunctions start-execution`,
`describe-execution`, and `stop-execution`. For local AWS operations in the
managed environment use `with-cred -- aws ...`; elsewhere use normal AWS role
credentials. Native retries and redrives retain native AWS semantics.

The DLQ backlog alarm uses the platform's existing SNS alarm topic as an AWS
delivery fallback. Cross-project execution logs and failure alerts use the
shared Ahara Grafana dashboard. Inventory comes from the registry; absence of
executions does not mean a pipeline is unregistered.
