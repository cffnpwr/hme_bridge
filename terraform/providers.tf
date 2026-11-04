provider "cloudflare" {}

provider "github" {
  owner = "cffnpwr"
  # NOTE: CIのplanのGITHUB_TOKENはtfcmt用のActionsのトークンのため、変数で明示的に指定
  token = var.github_token
}
