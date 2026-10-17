terraform {
  required_version = ">= 1.10.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }

  # bucket / key / endpoints は利用者ごとに異なるので、action が -backend-config で渡す。
  backend "s3" {
    region = "auto"

    # R2 は AWS ではないので AWS 固有のチェックを無効にする。
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}

provider "cloudflare" {}
