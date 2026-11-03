# NOTE: バージョンのアップロード・デプロイメント・workers.devの設定・observabilityは`cf deploy`が管理するため、Terraformでは指定しない
resource "cloudflare_worker" "hme_bridge" {
  account_id = local.cloudflare_account_id
  name       = "hme-bridge"
}

resource "cloudflare_workers_kv_namespace" "hme_bridge_creds" {
  account_id = local.cloudflare_account_id
  title      = "hme-bridge-creds"
}

resource "cloudflare_workers_custom_domain" "hme_bridge" {
  account_id = local.cloudflare_account_id
  zone_id    = data.cloudflare_zone.cffnpwr_dev.zone_id
  hostname   = "hme-bridge.${data.cloudflare_zone.cffnpwr_dev.name}"
  service    = cloudflare_worker.hme_bridge.name
}
