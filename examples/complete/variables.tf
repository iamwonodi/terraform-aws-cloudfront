
variable "project_name" {
  type        = string
  description = "Project identifier."
  default     = "example"
}

variable "environment" {
  type        = string
  description = "Deployment environment used."
  default     = "development"
}

variable "comment" {
  type        = string
  description = "Description of the CloudFront distribution."
  default     = "Complete CloudFront module example"
}

variable "s3_origin_domain_name" {
  type        = string
  description = "DNS name of the existing S3 origin."
}

variable "s3_origin_access_control_id" {
  type        = string
  description = "Existing CloudFront Origin Access Control ID associated with the S3 origin."
}

variable "application_origin_domain_name" {
  type        = string
  description = "DNS name of the existing application origin, such as an ALB."
}

variable "aliases" {
  type        = list(string)
  description = "Optional alternate domain names for the distribution."
  default     = []
}

variable "acm_certificate_arn" {
  type        = string
  description = "Optional ACM certificate ARN in us-east-1 for the alternate domain names."
  default     = null
}

variable "logging_destination_arn" {
  type        = string
  description = "ARN of the existing S3 bucket that will receive CloudFront Standard Logging v2 access logs."
}

variable "web_acl_id" {
  type        = string
  description = "Optional AWS WAF Web ACL ARN."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Additional tags for the CloudFront distribution."
  default     = {}
}