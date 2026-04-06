output "function_names" {
  description = "Map of lambda key → function name"
  value       = { for k, v in module.lambda : k => v.function_name }
}

output "function_arns" {
  description = "Map of lambda key → function ARN"
  value       = { for k, v in module.lambda : k => v.function_arn }
}

output "role_arn" {
  description = "IAM role ARN shared by all Lambdas in this module"
  value       = aws_iam_role.lambda.arn
}

output "role_name" {
  description = "IAM role name shared by all Lambdas in this module"
  value       = aws_iam_role.lambda.name
}

output "security_group_id" {
  description = "Security group ID shared by all Lambdas in this module"
  value       = aws_security_group.lambda.id
}

output "hostname" {
  value = var.hostname
}
