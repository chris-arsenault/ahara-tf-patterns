output "hostname" {
  value = var.hostname
}

output "url" {
  value = "https://${var.hostname}"
}
