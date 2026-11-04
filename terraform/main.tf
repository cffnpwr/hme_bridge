locals {
  cloudflare_account_id = "086a84b440e09bc83330fe07f1966f5d"
  # NOTE: アカウントトークンには説明を設定できないため、ダッシュボードで人が作成したトークンと名前で区別する
  #       他のリポジトリが作成したトークンと区別するためリポジトリ名を付ける
  cloudflare_account_token_name_prefix = "[managed by terraform] hme_bridge/"

  github_repository    = "hme_bridge"
  github_app_client_id = "Iv23lik6Pnc4eS9iNx1b"
}
