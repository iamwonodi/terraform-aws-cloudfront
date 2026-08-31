output "distribution_id" {
  description = "ID of the CloudFront distribution."
  value       = module.cloudfront.distribution_id
}

output "distribution_arn" {
  description = "ARN of the CloudFront distribution."
  value       = module.cloudfront.distribution_arn
}

output "distribution_domain_name" {
  description = "CloudFront distribution domain name."
  value       = module.cloudfront.distribution_domain_name
}

output "distribution_hosted_zone_id" {
  description = "Route 53 hosted zone ID associated with the distribution."
  value       = module.cloudfront.distribution_hosted_zone_id
}

output "status" {
  description = "Current CloudFront distribution status."
  value       = module.cloudfront.status
}

output "logging_delivery_source_arn" {
  description = "ARN of the CloudWatch Logs delivery source for CloudFront access logs."
  value       = module.cloudfront.logging_delivery_source_arn
}

output "logging_delivery_destination_arn" {
  description = "ARN of the CloudWatch Logs delivery destination."
  value       = module.cloudfront.logging_delivery_destination_arn
}