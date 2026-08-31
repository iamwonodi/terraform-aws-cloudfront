################################################################################
# CORE IDENTIFICATION
################################################################################

variable "project_name" {
  type        = string
  description = "Project name."

  validation {
    condition     = trimspace(var.project_name) != ""
    error_message = "project_name must not be empty."
  }
}


variable "environment" {
  type        = string
  description = "Environment associated with the module."

  validation {
    condition     = trimspace(var.environment) != ""
    error_message = "environment must not be empty."
  }
}


variable "comment" {
  type        = string
  description = "Comment describing the purpose of the CloudFront distribution."

  validation {
    condition     = trimspace(var.comment) != ""
    error_message = "comment must not be empty."
  }
}

variable "origins" {
  type = map(object({
    domain_name = string
    origin_type = string
    origin_path = optional(string, "")

    origin_access_control_id = optional(string)

    s3_origin_config = optional(object({
      origin_access_identity = optional(string, "")
    }))

    custom_origin_config = optional(object({
      http_port                = optional(number, 80)
      https_port               = optional(number, 443)
      origin_protocol_policy   = optional(string, "https-only")
      origin_ssl_protocols     = optional(list(string), ["TLSv1.2"])
      origin_read_timeout      = optional(number, 30)
      origin_keepalive_timeout = optional(number, 5)
    }))
  }))

  description = "Map of CloudFront origins keyed by the origin ID used by cache behaviors."

  validation {
    condition     = length(var.origins) > 0
    error_message = "At least one CloudFront origin must be defined."
  }

  validation {
    condition = alltrue([
      for origin in values(var.origins) :
      contains(["s3", "custom"], origin.origin_type)
    ])

    error_message = "Each origin_type must be either \"s3\" or \"custom\"."
  }

  validation {
    condition = alltrue([
      for origin in values(var.origins) :
      trimspace(origin.domain_name) != ""
    ])

    error_message = "Every CloudFront origin must have a non-empty domain_name."
  }

  validation {
    condition = alltrue([
      for origin in values(var.origins) :
      (
        origin.origin_type == "s3"
        ? origin.s3_origin_config != null && origin.custom_origin_config == null
        : origin.custom_origin_config != null && origin.s3_origin_config == null
      )
    ])

    error_message = "S3 origins require s3_origin_config and must not define custom_origin_config; custom origins require custom_origin_config and must not define s3_origin_config."
  }

  validation {
    condition = alltrue([
      for origin in values(var.origins) :
      origin.origin_type != "s3" || (
        origin.origin_access_control_id != null ||
        (
          origin.s3_origin_config != null &&
          trimspace(origin.s3_origin_config.origin_access_identity) != ""
        )
      )
    ])

    error_message = "Each S3 origin must define either origin_access_control_id or s3_origin_config.origin_access_identity."
  }

  validation {
    condition = alltrue([
      for origin in values(var.origins) :
      origin.origin_type != "custom" || origin.origin_access_control_id == null
    ])

    error_message = "origin_access_control_id is only supported for S3 origins in this module."
  }

  validation {
    condition = alltrue([
      for origin in values(var.origins) :
      origin.origin_type != "custom" || (
        origin.custom_origin_config.origin_protocol_policy == "http-only" ||
        origin.custom_origin_config.origin_protocol_policy == "https-only" ||
        origin.custom_origin_config.origin_protocol_policy == "match-viewer"
      )
    ])

    error_message = "Custom origin_protocol_policy must be http-only, https-only, or match-viewer."
  }

  validation {
    condition = alltrue(flatten([
      for origin in values(var.origins) : [
        origin.origin_type != "custom" || (
          origin.custom_origin_config.http_port >= 1 &&
          origin.custom_origin_config.http_port <= 65535 &&
          origin.custom_origin_config.https_port >= 1 &&
          origin.custom_origin_config.https_port <= 65535
        )
      ]
    ]))

    error_message = "Custom origin HTTP and HTTPS ports must be between 1 and 65535."
  }

  validation {
    condition = alltrue(flatten([
      for origin in values(var.origins) : [
        origin.origin_type != "custom" || (
          origin.custom_origin_config.origin_read_timeout >= 1 &&
          origin.custom_origin_config.origin_read_timeout <= 60 &&
          origin.custom_origin_config.origin_keepalive_timeout >= 1 &&
          origin.custom_origin_config.origin_keepalive_timeout <= 60
        )
      ]
    ]))

    error_message = "Custom origin read and keepalive timeouts must be between 1 and 60 seconds."
  }

  validation {
    condition = alltrue(flatten([
      for origin in values(var.origins) : [
        for protocol in origin.origin_type == "custom" ? origin.custom_origin_config.origin_ssl_protocols : [] :
        contains(["TLSv1", "TLSv1.1", "TLSv1.2"], protocol)
      ]
    ]))

    error_message = "Custom origin SSL protocols must be TLSv1, TLSv1.1, or TLSv1.2."
  }
}

variable "default_cache_behavior" {
  type = object({
    target_origin_id           = string
    viewer_protocol_policy     = optional(string, "redirect-to-https")
    allowed_methods            = optional(list(string), ["GET", "HEAD", "OPTIONS"])
    cached_methods             = optional(list(string), ["GET", "HEAD"])
    cache_policy_id            = optional(string, "658327ea-f89d-4fab-a63d-7e88639e58f6")
    origin_request_policy_id   = optional(string)
    response_headers_policy_id = optional(string)
    compress                   = optional(bool, true)
  })

  description = "Default cache behavior for requests that do not match an ordered cache behavior."

  validation {
    condition = contains(
      ["allow-all", "https-only", "redirect-to-https"],
      var.default_cache_behavior.viewer_protocol_policy
    )

    error_message = "default_cache_behavior.viewer_protocol_policy must be allow-all, https-only, or redirect-to-https."
  }

  validation {
    condition = alltrue([
      for method in var.default_cache_behavior.allowed_methods :
      contains(
        ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"],
        method
      )
    ])

    error_message = "default_cache_behavior.allowed_methods contains an unsupported HTTP method."
  }

  validation {
    condition = alltrue([
      for method in var.default_cache_behavior.cached_methods :
      contains(
        ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"],
        method
      )
    ])

    error_message = "default_cache_behavior.cached_methods contains an unsupported HTTP method."
  }

  validation {
    condition = alltrue([
      for method in var.default_cache_behavior.cached_methods :
      contains(var.default_cache_behavior.allowed_methods, method)
    ])

    error_message = "Every cached method must also be included in allowed_methods."
  }

  validation {
    condition = length(var.default_cache_behavior.allowed_methods) > 0 && length(var.default_cache_behavior.cached_methods) > 0

    error_message = "default_cache_behavior allowed_methods and cached_methods must not be empty."
  }
}

variable "ordered_cache_behaviors" {
  type = list(object({
    path_pattern               = string
    target_origin_id           = string
    viewer_protocol_policy     = optional(string, "redirect-to-https")
    allowed_methods            = optional(list(string), ["GET", "HEAD", "OPTIONS"])
    cached_methods             = optional(list(string), ["GET", "HEAD"])
    cache_policy_id            = optional(string, "658327ea-f89d-4fab-a63d-7e88639e58f6")
    origin_request_policy_id   = optional(string)
    response_headers_policy_id = optional(string)
    compress                   = optional(bool, true)
  }))

  description = "Ordered cache behaviors evaluated before the default cache behavior."

  default = []

  validation {
    condition = alltrue([
      for behavior in var.ordered_cache_behaviors :
      trimspace(behavior.path_pattern) != ""
    ])

    error_message = "Every ordered cache behavior must have a non-empty path_pattern."
  }

  validation {
    condition = alltrue([
      for behavior in var.ordered_cache_behaviors :
      contains(
        ["allow-all", "https-only", "redirect-to-https"],
        behavior.viewer_protocol_policy
      )
    ])

    error_message = "Every ordered cache behavior must use a valid viewer_protocol_policy."
  }

  validation {
    condition = alltrue(flatten([
      for behavior in var.ordered_cache_behaviors : [
        for method in behavior.allowed_methods :
        contains(
          ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"],
          method
        )
      ]
    ]))

    error_message = "An ordered cache behavior contains an unsupported allowed HTTP method."
  }

  validation {
    condition = alltrue(flatten([
      for behavior in var.ordered_cache_behaviors : [
        for method in behavior.cached_methods :
        contains(
          ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"],
          method
        )
      ]
    ]))

    error_message = "An ordered cache behavior contains an unsupported cached HTTP method."
  }

  validation {
    condition = alltrue([
      for behavior in var.ordered_cache_behaviors :
      alltrue([
        for method in behavior.cached_methods :
        contains(behavior.allowed_methods, method)
      ])
    ])

    error_message = "Every cached method in an ordered cache behavior must also be included in allowed_methods."
  }
}


###################################################################################
# CUSTOM ERROR RESPONSES
###################################################################################

variable "custom_error_responses" {
  type = list(object({
    error_code            = number
    response_code         = optional(number)
    response_page_path    = optional(string)
    error_caching_min_ttl = optional(number)
  }))

  description = <<-EOT
    Custom error responses returned by CloudFront when the configured origin
    returns an HTTP error status code.

    Each object may define:
      - error_code: The HTTP error status code CloudFront should intercept.
      - response_code: The HTTP status code returned to the viewer.
      - response_page_path: The path to the custom error page.
      - error_caching_min_ttl: Minimum amount of time, in seconds, that CloudFront
        caches the error response.

    Example:
      [
        {
          error_code            = 404
          response_code         = 404
          response_page_path    = "/errors/404.html"
          error_caching_min_ttl = 60
        }
      ]

    When response_code or response_page_path is omitted, CloudFront uses its
    default behavior for that attribute.
  EOT

  default = []

  validation {
    condition = alltrue([
      for error in var.custom_error_responses :
      contains(
        [
          400, 401, 403, 404, 405, 406, 407, 408, 409, 410,
          411, 412, 413, 414, 415, 416, 417, 418, 421, 422,
          423, 424, 425, 426, 428, 429, 431, 451,
          500, 501, 502, 503, 504, 505, 506, 507, 508, 509,
          510, 511
        ],
        error.error_code
      )
    ])

    error_message = "Each custom error response must use a supported HTTP error status code."
  }

  validation {
    condition = alltrue([
      for error in var.custom_error_responses :
      error.error_caching_min_ttl == null ||
      error.error_caching_min_ttl >= 0
    ])

    error_message = "error_caching_min_ttl must be greater than or equal to 0."
  }

  validation {
    condition = alltrue([
      for error in var.custom_error_responses :
      error.response_code == null ||
      contains(
        [
          200, 201, 202, 203, 204, 205, 206,
          300, 301, 302, 303, 304, 307, 308,
          400, 401, 403, 404, 405, 406, 407, 408, 409, 410,
          411, 412, 413, 414, 415, 416, 417, 418, 421, 422,
          423, 424, 425, 426, 428, 429, 431, 451,
          500, 501, 502, 503, 504, 505, 506, 507, 508,
          509, 510, 511
        ],
        error.response_code
      )
    ])

    error_message = "response_code must be a valid HTTP response status code."
  }

  validation {
    condition = alltrue([
      for error in var.custom_error_responses :
      error.response_page_path == null ||
      startswith(error.response_page_path, "/")
    ])

    error_message = "response_page_path must begin with '/'."
  }
}

variable "origin_groups" {
  type = map(object({
    primary_origin_id     = string
    failover_origin_id    = string
    failover_status_codes = list(number)
  }))

  description = "Optional CloudFront origin groups used to provide origin failover."

  default = {}

  validation {
    condition = alltrue([
      for group in values(var.origin_groups) :
      group.primary_origin_id != group.failover_origin_id
    ])

    error_message = "An origin group must reference two different origins."
  }

  validation {
    condition = alltrue(flatten([
      for group in values(var.origin_groups) : [
        for code in group.failover_status_codes :
        code >= 400 && code <= 599
      ]
    ]))

    error_message = "Origin group failover status codes must be valid HTTP 4xx or 5xx status codes."
  }

  validation {
    condition = alltrue([
      for group in values(var.origin_groups) :
      length(group.failover_status_codes) > 0
    ])

    error_message = "Every origin group must define at least one failover status code."
  }
}

variable "enabled" {
  type        = bool
  description = "Whether the CloudFront distribution is enabled."
  default     = true
}

variable "is_ipv6_enabled" {
  type        = bool
  description = "Whether IPv6 is enabled for the CloudFront distribution."
  default     = true
}

variable "http_version" {
  type        = string
  description = "Maximum HTTP version supported by the CloudFront distribution."
  default     = "http2"

  validation {
    condition = contains(
      ["http1.1", "http2", "http2and3", "http3"],
      var.http_version
    )

    error_message = "http_version must be http1.1, http2, http2and3, or http3."
  }
}

variable "price_class" {
  type        = string
  description = "CloudFront price class controlling the edge locations used by the distribution."
  default     = "PriceClass_100"

  validation {
    condition = contains(
      ["PriceClass_All", "PriceClass_200", "PriceClass_100"],
      var.price_class
    )

    error_message = "price_class must be PriceClass_All, PriceClass_200, or PriceClass_100."
  }
}

variable "default_root_object" {
  type        = string
  description = "Object CloudFront requests when a viewer requests the distribution root."
  default     = null #  "index.html"
}

variable "aliases" {
  type        = list(string)
  description = "Optional alternate domain names associated with the distribution."
  default     = []

  validation {
    condition = alltrue([
      for alias in var.aliases :
      trimspace(alias) != ""
    ])

    error_message = "CloudFront aliases must not contain empty strings."
  }

  validation {
    condition     = length(var.aliases) == length(toset(var.aliases))
    error_message = "CloudFront aliases must be unique."
  }
}

variable "acm_certificate_arn" {
  type        = string
  description = "Optional ACM certificate ARN used for alternate domain names. The certificate must be in us-east-1."
  default     = null

  validation {
    condition = (
      var.acm_certificate_arn == null ||
      can(regex("^arn:[^:]+:acm:[^:]+:[0-9]{12}:certificate/[0-9a-fA-F-]+$", var.acm_certificate_arn))
    )

    error_message = "acm_certificate_arn must be a valid ACM certificate ARN."
  }
}

variable "minimum_protocol_version" {
  type        = string
  description = "Minimum TLS protocol version for viewers using the supplied ACM certificate."
  default     = "TLSv1.2_2021"

  validation {
    condition = contains(
      [
        "TLSv1",
        "TLSv1_2016",
        "TLSv1.1_2016",
        "TLSv1.2_2018",
        "TLSv1.2_2019",
        "TLSv1.2_2021",
        "TLSv1.2_2025"
      ],
      var.minimum_protocol_version
    )

    error_message = "minimum_protocol_version must be a supported CloudFront TLS security policy."
  }
}


################################################################################
# STANDARD LOGGING V2
################################################################################

variable "logging" {
  type = object({
    enabled = optional(bool, false)

    source_name = optional(string, "my-cloudfront-access-logs-source")

    destination_type = optional(string, "s3")

    destination_arn = optional(string)

    destination_name = optional(string, "my-cloudfront-access-logs-destination")

    region = optional(string, "us-east-1")

    output_format = optional(string, "json")

    field_delimiter = optional(string, ",")

    record_fields = optional(list(string), [])

    s3 = optional(object({
      suffix_path = optional(
        string,
        "/{DistributionId}/{yyyy}/{MM}/{dd}/{HH}"
      )
    }))
  })

  description = <<-EOT
    Configuration for CloudFront Standard Logging v2.

    The destination resource must already exist. This module creates the
    CloudWatch Logs delivery source, delivery destination, and delivery
    connection required to send CloudFront access logs to that destination.
  EOT

  default = {}

  validation {
    condition = contains(
      ["s3", "cloudwatch_logs", "firehose"],
      var.logging.destination_type
    )

    error_message = "logging.destination_type must be s3, cloudwatch_logs, or firehose."
  }

  validation {
    condition = (
      !var.logging.enabled ||
      var.logging.destination_arn != null
    )

    error_message = "logging.destination_arn must be provided when Standard Logging v2 is enabled."
  }

  validation {
    condition = (
      !var.logging.enabled ||
      var.logging.destination_name != null
    )

    error_message = "logging.destination_name must be provided when Standard Logging v2 is enabled."
  }

  validation {
    condition = contains(
      ["json", "plain", "w3c", "raw", "parquet"],
      var.logging.output_format
    )

    error_message = "logging.output_format must be json, plain, w3c, raw, or parquet."
  }

  validation {
    condition = (
      var.logging.destination_type != "s3" ||
      var.logging.output_format != "parquet" ||
      var.logging.enabled
    )

    error_message = "Parquet output is only valid for an enabled S3 logging destination."
  }

  validation {
    condition = (
      var.logging.destination_type == "s3" ||
      var.logging.output_format != "parquet"
    )

    error_message = "Parquet output is supported only for S3 logging destinations."
  }

  validation {
    condition = (
      !var.logging.enabled ||
      length(var.logging.record_fields) == 0 ||
      length(distinct(var.logging.record_fields)) == length(var.logging.record_fields)
    )

    error_message = "logging.record_fields must not contain duplicate field names."
  }

  validation {
    condition = (
      !var.logging.enabled ||
      var.logging.field_delimiter != ""
    )

    error_message = "logging.field_delimiter must not be empty when logging is enabled."
  }

  validation {
    condition = (
      !var.logging.enabled ||
      var.logging.destination_type != "s3" ||
      var.logging.s3 != null
    )

    error_message = "logging.s3 must be configured when destination_type is s3 and logging is enabled."
  }
}


variable "web_acl_id" {
  type        = string
  description = "Optional AWS WAF Web ACL ARN associated with the distribution."
  default     = null

  validation {
    condition = (
      var.web_acl_id == null ||
      can(regex("^arn:[^:]+:wafv2:[^:]+:[0-9]{12}:(global|regional)/webacl/.+$", var.web_acl_id))
    )

    error_message = "web_acl_id must be a valid AWS WAFv2 Web ACL ARN."
  }
}

variable "tags" {
  type        = map(string)
  description = "Additional tags applied to the CloudFront distribution."
  default     = {}
}