resource "cloudflare_zero_trust_access_policy" "allowed_emails" {
  account_id = var.account_id
  name       = "${var.worker_name} - allowed emails"
  decision   = "allow"

  include = [
    for email in var.allowed_emails : {
      email = { email = email }
    }
  ]
}

resource "cloudflare_zero_trust_access_application" "site" {
  account_id       = var.account_id
  name             = var.worker_name
  domain           = var.domain
  type             = "self_hosted"
  session_duration = var.session_duration

  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.allowed_emails.id
      precedence = 1
    }
  ]
}
