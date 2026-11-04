import { bindings, defineConfig } from "cf/config";

export default defineConfig({
  worker: {
    name: "hme-bridge",
    compatibilityDate: "2025-08-23",
    entrypoint: "build/worker/shim.mjs",
    env: {
      /*
       * NOTE: KV namespaceはTerraformで作成するため、
       *       IDには`mise run tf output -raw kv_namespace_id`の値を記載する
       */
      HME_BRIDGE_CREDS: bindings.kv({
        id: "5779685861724952841adea924e863c9",
      }),
      ADMIN_TOKEN: bindings.secret(),
    },
  },
});
