variable "github_token" {
  description = "GitHub providerのトークン（未設定ならGITHUB_TOKEN環境変数か`gh auth token`を使う）"
  type        = string
  default     = null
  sensitive   = true
}

# NOTE: GitHubの画面でしか作れないGitHub Appの秘密鍵の、変数での受け取り
variable "github_app_private_key" {
  description = "CIのplan・applyがGitHub providerのトークンを発行するときに使うGitHub Appの秘密鍵（PEM）"
  type        = string
  sensitive   = true
}

# NOTE: CIのplan・applyでは未設定のため、空文字列を既定値にする
#       CIのjobが登録済みのシークレットを空文字列で上書きしないよう、シークレットの値の変更は無視する
variable "cloudflare_api_token_read_write" {
  description = "CIのapplyがCloudflare providerで使う、読み書きできるAPIトークン"
  type        = string
  default     = ""
  sensitive   = true
}
