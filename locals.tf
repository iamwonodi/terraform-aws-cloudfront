locals {
  # --------------------------------------------------------------------------
  # CloudFront origin IDs are derived from the caller's map keys. This provides
  # stable identifiers that can be referenced directly by cache behaviors and
  # origin groups without relying on positional list indexes.
  # --------------------------------------------------------------------------
  origin_ids = toset(keys(var.origins))

  # --------------------------------------------------------------------------
  # Common tags provide a consistent Terraform ownership marker while allowing
  # callers to supply additional organizational tags.
  # --------------------------------------------------------------------------
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}