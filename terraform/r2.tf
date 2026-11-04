resource "cloudflare_r2_bucket" "tfstate" {
  account_id = local.cloudflare_account_id
  name       = "hme-bridge-tfstate"

  lifecycle {
    # NOTE: 破棄すると全リソースのstateが失われる
    prevent_destroy = true
  }
}
