output "kv_namespace_id" {
  description = "`cloudflare.config.ts`の`HME_BRIDGE_CREDS`に記載するKV namespaceのID"
  value       = cloudflare_workers_kv_namespace.hme_bridge_creds.id
}

# NOTE: `cf deploy --secrets-file`と`wrangler secret bulk`が読み込むJSONの形式で出力する
output "worker_secrets" {
  description = "Workerに設定するシークレット"
  value = {
    ADMIN_TOKEN = random_password.admin_token.result
  }
  sensitive = true
}

output "worker_domain" {
  description = "Workerが使用するドメイン"
  value       = cloudflare_workers_custom_domain.hme_bridge.hostname
}
