################################################################################
# CLOUDFRONT DISTRIBUTION
################################################################################

# ------------------------------------------------------------------------------
# CloudFront distribution
#
# The distribution is intentionally the only AWS resource owned by this
# module. Origins, ACM certificates, WAF policies, Route 53 records, cache
# policies, and response-header policies have independent lifecycles and are
# therefore supplied by the caller.
#
# Multiple origins are supported so a single distribution can route different
# URL paths to different backends, such as S3 for static content and an ALB for
# application/API traffic.
# ------------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "this" {
  enabled         = var.enabled
  is_ipv6_enabled = var.is_ipv6_enabled
  http_version    = var.http_version
  price_class     = var.price_class
  comment         = var.comment

  default_root_object = var.default_root_object
  aliases             = var.aliases

  # ---------------------------------------------------------------------------
  # Validate references between cache behaviors and the origin map before
  # Terraform attempts to create the CloudFront distribution.
  # ---------------------------------------------------------------------------
  lifecycle {
    precondition {
      condition = contains(
        local.origin_ids,
        var.default_cache_behavior.target_origin_id
      )

      error_message = "default_cache_behavior.target_origin_id must reference an origin defined in origins."
    }

    precondition {
      condition = alltrue([
        for behavior in var.ordered_cache_behaviors :
        contains(local.origin_ids, behavior.target_origin_id)
      ])

      error_message = "Every ordered cache behavior target_origin_id must reference an origin defined in origins."
    }

    precondition {
      condition = alltrue(flatten([
        for group in values(var.origin_groups) : [
          contains(local.origin_ids, group.primary_origin_id),
          contains(local.origin_ids, group.failover_origin_id)
        ]
      ]))

      error_message = "Every origin group primary_origin_id and failover_origin_id must reference an origin defined in origins."
    }

    precondition {
      condition = (
        length(var.aliases) == 0 ||
        var.acm_certificate_arn != null
      )

      error_message = "acm_certificate_arn must be provided when aliases are configured."
    }

    precondition {
      condition = (
        var.acm_certificate_arn == null ||
        length(var.aliases) > 0
      )

      error_message = "acm_certificate_arn should only be provided when aliases are configured."
    }
  }

  # ---------------------------------------------------------------------------
  # Origins
  #
  # Each map key becomes the stable CloudFront origin_id. The caller controls
  # the origin endpoint while this module controls how CloudFront represents
  # and connects to that endpoint.
  # ---------------------------------------------------------------------------
  dynamic "origin" {
    for_each = var.origins

    content {
      domain_name = origin.value.domain_name
      origin_id   = origin.key
      origin_path = origin.value.origin_path

      origin_access_control_id = origin.value.origin_access_control_id

      dynamic "s3_origin_config" {
        for_each = origin.value.origin_type == "s3" ? [origin.value.s3_origin_config] : []

        content {
          origin_access_identity = s3_origin_config.value.origin_access_identity
        }
      }

      dynamic "custom_origin_config" {
        for_each = origin.value.origin_type == "custom" ? [origin.value.custom_origin_config] : []

        content {
          http_port                = custom_origin_config.value.http_port
          https_port               = custom_origin_config.value.https_port
          origin_protocol_policy   = custom_origin_config.value.origin_protocol_policy
          origin_ssl_protocols     = custom_origin_config.value.origin_ssl_protocols
          origin_read_timeout      = custom_origin_config.value.origin_read_timeout
          origin_keepalive_timeout = custom_origin_config.value.origin_keepalive_timeout
        }
      }
    }
  }

  # ---------------------------------------------------------------------------
  # Origin groups
  #
  # Origin groups provide failover rather than ordinary path-based routing.
  # CloudFront uses the primary origin first and can switch to the failover
  # origin when one of the configured HTTP status codes is returned.
  # ---------------------------------------------------------------------------
  dynamic "origin_group" {
    for_each = var.origin_groups

    content {
      origin_id = origin_group.key

      failover_criteria {
        status_codes = origin_group.value.failover_status_codes
      }

      member {
        origin_id = origin_group.value.primary_origin_id
      }

      member {
        origin_id = origin_group.value.failover_origin_id
      }
    }
  }

  # ---------------------------------------------------------------------------
  # Default cache behavior
  #
  # Every request that does not match an ordered cache behavior reaches this
  # behavior. AWS-managed CachingOptimized is the default cache policy so the
  # module does not create and own a custom cache policy.
  # ---------------------------------------------------------------------------
  default_cache_behavior {
    target_origin_id       = var.default_cache_behavior.target_origin_id
    viewer_protocol_policy = var.default_cache_behavior.viewer_protocol_policy

    allowed_methods = var.default_cache_behavior.allowed_methods
    cached_methods  = var.default_cache_behavior.cached_methods

    cache_policy_id            = var.default_cache_behavior.cache_policy_id
    origin_request_policy_id   = var.default_cache_behavior.origin_request_policy_id
    response_headers_policy_id = var.default_cache_behavior.response_headers_policy_id

    compress = var.default_cache_behavior.compress
  }

  # ---------------------------------------------------------------------------
  # Ordered cache behaviors
  #
  # These are evaluated in the order supplied by the caller. They allow paths
  # such as /static/* and /api/* to use different origins or caching policies.
  # ---------------------------------------------------------------------------
  dynamic "ordered_cache_behavior" {
    for_each = var.ordered_cache_behaviors

    content {
      path_pattern           = ordered_cache_behavior.value.path_pattern
      target_origin_id       = ordered_cache_behavior.value.target_origin_id
      viewer_protocol_policy = ordered_cache_behavior.value.viewer_protocol_policy

      allowed_methods = ordered_cache_behavior.value.allowed_methods
      cached_methods  = ordered_cache_behavior.value.cached_methods

      cache_policy_id            = ordered_cache_behavior.value.cache_policy_id
      origin_request_policy_id   = ordered_cache_behavior.value.origin_request_policy_id
      response_headers_policy_id = ordered_cache_behavior.value.response_headers_policy_id

      compress = ordered_cache_behavior.value.compress
    }
  }


  #################################################################################
  # CUSTOM ERROR RESPONSES
  #################################################################################

  dynamic "custom_error_response" {
    for_each = var.custom_error_responses

    content {
      error_code            = custom_error_response.value.error_code
      response_code         = custom_error_response.value.response_code
      response_page_path    = custom_error_response.value.response_page_path
      error_caching_min_ttl = custom_error_response.value.error_caching_min_ttl
    }
  }


  # ---------------------------------------------------------------------------
  # CloudFront distributions require an explicit geographic restriction block.
  # No restriction is imposed by default so the module remains globally usable.
  # ---------------------------------------------------------------------------
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # ---------------------------------------------------------------------------
  # Viewer certificate
  #
  # The CloudFront-managed certificate is used when no alternate domain is
  # configured. Custom aliases require a caller-managed ACM certificate.
  # ---------------------------------------------------------------------------
  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == null
    acm_certificate_arn            = var.acm_certificate_arn

    ssl_support_method       = var.acm_certificate_arn != null ? "sni-only" : null
    minimum_protocol_version = var.acm_certificate_arn != null ? var.minimum_protocol_version : null
  }

  # ---------------------------------------------------------------------------
  # WAF remains externally managed because security policy can have an
  # independent lifecycle and may be shared by several distributions.
  # ---------------------------------------------------------------------------
  web_acl_id = var.web_acl_id

  tags = local.common_tags
}


################################################################################
# CLOUDFRONT STANDARD LOGGING V2
################################################################################

# ------------------------------------------------------------------------------
# CloudWatch Logs Delivery Source
#
# CloudFront is the resource producing the ACCESS_LOGS stream.
#
# The delivery source must be created in us-east-1 because CloudFront is a
# global service and AWS requires the CloudWatch Logs API configuration for
# CloudFront logging to be performed through us-east-1.
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_delivery_source" "cloudfront" {
  count = var.logging.enabled ? 1 : 0

  region = var.logging.region

  name         = var.logging.source_name
  log_type     = "ACCESS_LOGS"
  resource_arn = aws_cloudfront_distribution.this.arn

  tags = local.common_tags

  depends_on = [
    aws_cloudfront_distribution.this
  ]
}


# ------------------------------------------------------------------------------
# CloudWatch Logs Delivery Destination
#
# This resource represents the externally managed destination that receives
# the CloudFront access logs.
#
# The actual S3 bucket, CloudWatch log group, or Firehose stream is NOT created
# by this module.
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_delivery_destination" "cloudfront" {
  count = var.logging.enabled ? 1 : 0

  region = var.logging.region

  name = var.logging.destination_name

  delivery_destination_configuration {
    destination_resource_arn = var.logging.destination_arn
  }

  tags = local.common_tags
}


# ------------------------------------------------------------------------------
# CloudWatch Logs Delivery
#
# This resource connects the CloudFront ACCESS_LOGS source to the configured
# destination.
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_delivery" "cloudfront" {
  count = var.logging.enabled ? 1 : 0

  region = var.logging.region

  delivery_source_name     = aws_cloudwatch_log_delivery_source.cloudfront[0].name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.cloudfront[0].arn

  field_delimiter = var.logging.field_delimiter
  record_fields   = var.logging.record_fields

  dynamic "s3_delivery_configuration" {
    for_each = var.logging.destination_type == "s3" ? [var.logging.s3] : []

    content {
      suffix_path = s3_delivery_configuration.value.suffix_path
    }
  }

  depends_on = [
    aws_cloudwatch_log_delivery_source.cloudfront,
    aws_cloudwatch_log_delivery_destination.cloudfront
  ]
}