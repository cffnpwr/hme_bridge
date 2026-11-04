terraform {
  required_version = "1.17.1"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.28.1"
    }
    github = {
      source  = "integrations/github"
      version = "6.13.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.1"
    }
  }
}
