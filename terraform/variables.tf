variable "account_id" {
  type = string
}

variable "worker_name" {
  type = string
}

variable "domain" {
  description = "Access で保護するホスト名 (例: <worker>.<subdomain>.workers.dev)"
  type        = string
}

variable "allowed_emails" {
  type = list(string)

  # 空リストだと誰も通れないだけだが、設定ミスを早く気付けるように弾く。
  validation {
    condition     = length(var.allowed_emails) > 0
    error_message = "allowed_emails must not be empty."
  }
}

variable "session_duration" {
  type    = string
  default = "24h"
}
