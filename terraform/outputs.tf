output "kv_namespace_id" {
  description = "`cloudflare.config.ts`の`HME_BRIDGE_CREDS`に記載するKV namespaceのID"
  value       = cloudflare_workers_kv_namespace.hme_bridge_creds.id
}
