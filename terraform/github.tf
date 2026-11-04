resource "github_repository_environment" "terraform_apply" {
  repository  = local.github_repository
  environment = "terraform-apply"

  # NOTE: masterへのマージ後のapplyだけがシークレットを読めるよう、masterブランチに限定
  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "terraform_apply_master" {
  repository     = github_repository_environment.terraform_apply.repository
  environment    = github_repository_environment.terraform_apply.environment
  branch_pattern = "master"
}

resource "github_repository_environment" "terraform_plan" {
  repository  = local.github_repository
  environment = "terraform-plan"
}

# NOTE: applyのS3 backendの認証情報は、workflowがCLOUDFLARE_API_TOKENから作る
resource "github_actions_environment_secret" "terraform_plan_aws_access_key_id" {
  repository  = local.github_repository
  environment = github_repository_environment.terraform_plan.environment
  secret_name = "AWS_ACCESS_KEY_ID"
  value       = cloudflare_account_token.terraform_plan.id
}

resource "github_actions_environment_secret" "terraform_plan_aws_secret_access_key" {
  repository  = local.github_repository
  environment = github_repository_environment.terraform_plan.environment
  secret_name = "AWS_SECRET_ACCESS_KEY"
  # NOTE: R2のSecret Access Keyは、APIトークンの値をSHA-256でハッシュ化した値
  value = sha256(cloudflare_account_token.terraform_plan.value)
}

resource "github_actions_environment_secret" "terraform_plan_cloudflare_api_token" {
  repository  = local.github_repository
  environment = github_repository_environment.terraform_plan.environment
  secret_name = "CLOUDFLARE_API_TOKEN"
  value       = cloudflare_account_token.terraform_plan.value
}

# NOTE: APIトークンで作成したトークンにはAccount API Tokens Writeを付けられないため、ダッシュボードで作成したトークンを変数で受け取る
#       入力の値の更新は、手元で-replaceを指定してapplyする
resource "github_actions_environment_secret" "terraform_apply_cloudflare_api_token" {
  repository  = local.github_repository
  environment = github_repository_environment.terraform_apply.environment
  secret_name = "CLOUDFLARE_API_TOKEN"
  value       = var.cloudflare_api_token_read_write

  lifecycle {
    ignore_changes = [value]
  }
}

resource "github_actions_secret" "update_private_key" {
  repository  = local.github_repository
  secret_name = "UPDATE_PRIVATE_KEY"
  value       = var.github_app_private_key
}

resource "github_actions_variable" "update_client_id" {
  repository    = local.github_repository
  variable_name = "UPDATE_CLIENT_ID"
  value         = local.github_app_client_id
}
