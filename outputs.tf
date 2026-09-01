################################################################################
# CLOUD FRONT DISTRIBUTION OUTPUTS
################################################################################

output "distribution_id" {
  description = "ID of the CloudFront distribution."
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  description = "ARN of the CloudFront distribution."
  value       = aws_cloudfront_distribution.this.arn
}

output "distribution_domain_name" {
  description = "Domain name assigned to the CloudFront distribution."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "distribution_hosted_zone_id" {
  description = "Route 53 hosted zone ID associated with the CloudFront distribution."
  value       = aws_cloudfront_distribution.this.hosted_zone_id
}

output "status" {
  description = "Current deployment status of the CloudFront distribution."
  value       = aws_cloudfront_distribution.this.status
}

################################################################################
# S3 ORIGIN ACCESS CONTROL OUTPUTS
################################################################################

output "s3_origin_access_control_id" {
  description = "ID of the CloudFront Origin Access Control created by this module for S3 origins."
  value = try(
    aws_cloudfront_origin_access_control.s3[0].id,
    null
  )
}

output "s3_origin_access_control_arn" {
  description = "ARN of the CloudFront Origin Access Control created by this module for S3 origins."
  value = try(
    aws_cloudfront_origin_access_control.s3[0].arn,
    null
  )
}

################################################################################
# STANDARD LOGGING V2 OUTPUTS
################################################################################

output "logging_delivery_source_arn" {
  description = "ARN of the CloudWatch Logs delivery source for CloudFront access logs."
  value = try(
    aws_cloudwatch_log_delivery_source.cloudfront[0].arn,
    null
  )
}

output "logging_delivery_destination_arn" {
  description = "ARN of the CloudWatch Logs delivery destination."
  value = try(
    aws_cloudwatch_log_delivery_destination.cloudfront[0].arn,
    null
  )
}