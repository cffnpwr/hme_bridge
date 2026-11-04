locals {
  # NOTE: planは変更を適用しないため、planには読み取りだけを許可
  #       applyのCloudflare providerは、トークンの管理にAccount API Tokens Writeが必要
  #       APIトークンで作成したトークンにはこの権限を付けられないため、applyはダッシュボードで作成したトークンを使う
  terraform_plan_permission_groups = {
    # NOTE: stateの読み取りは、Workers R2 Storage Readで許可
    account = [
      "Account API Tokens Read",
      "Workers KV Storage Read",
      "Workers R2 Storage Read",
      "Workers Scripts Read",
    ]
    zone = ["Zone Read"]
  }
}

data "cloudflare_account_api_token_permission_groups_list" "terraform_plan" {
  for_each = toset(concat(local.terraform_plan_permission_groups.account, local.terraform_plan_permission_groups.zone))

  account_id = local.cloudflare_account_id
  name       = urlencode(each.key)
}

# NOTE: CIのplanが、S3 backendのstateの読み取りとCloudflare providerに使うトークン
resource "cloudflare_account_token" "terraform_plan" {
  account_id = local.cloudflare_account_id
  name       = "${local.cloudflare_account_token_name_prefix}terraform-plan"

  policies = [
    {
      effect = "allow"
      permission_groups = [
        for name in local.terraform_plan_permission_groups.account : { id = one(data.cloudflare_account_api_token_permission_groups_list.terraform_plan[name].result).id }
      ]
      resources = jsonencode({
        "com.cloudflare.api.account.${local.cloudflare_account_id}" = "*"
      })
    },
    {
      effect = "allow"
      permission_groups = [
        for name in local.terraform_plan_permission_groups.zone : { id = one(data.cloudflare_account_api_token_permission_groups_list.terraform_plan[name].result).id }
      ]
      resources = jsonencode({
        "com.cloudflare.api.account.zone.${data.cloudflare_zone.cffnpwr_dev.zone_id}" = "*"
      })
    },
  ]
}
