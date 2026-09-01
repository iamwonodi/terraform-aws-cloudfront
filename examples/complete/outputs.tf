################################################################################
# TERRAFORM AWS CLOUDFRONT MODULE
# COMPLETE EXAMPLE OUTPUTS
################################################################################


################################################################################
# CLOUDFRONT DISTRIBUTION
################################################################################

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution."
  value       = module.cloudfront.distribution_id
}


output "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution."
  value       = module.cloudfront.distribution_arn
}


output "cloudfront_distribution_domain_name" {
  description = "CloudFront-generated distribution domain name."
  value       = module.cloudfront.distribution_domain_name
}


output "cloudfront_distribution_hosted_zone_id" {
  description = "Route 53 hosted zone ID associated with the CloudFront distribution."
  value       = module.cloudfront.distribution_hosted_zone_id
}


output "cloudfront_status" {
  description = "Current deployment status of the CloudFront distribution."
  value       = module.cloudfront.status
}


################################################################################
# AUTOMATIC S3 ORIGIN ACCESS CONTROL
################################################################################

output "s3_origin_access_control_id" {
  description = "ID of the Origin Access Control automatically created by the CloudFront module."
  value       = module.cloudfront.s3_origin_access_control_id
}


output "s3_origin_access_control_arn" {
  description = "ARN of the Origin Access Control automatically created by the CloudFront module."
  value       = module.cloudfront.s3_origin_access_control_arn
}


################################################################################
# STANDARD LOGGING V2
################################################################################

output "logging_delivery_source_arn" {
  description = "ARN of the CloudFront Standard Logging v2 delivery source."
  value       = module.cloudfront.logging_delivery_source_arn
}


output "logging_delivery_destination_arn" {
  description = "ARN of the CloudFront Standard Logging v2 delivery destination."
  value       = module.cloudfront.logging_delivery_destination_arn
}