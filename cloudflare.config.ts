import { bindings, defineConfig } from "cf/config";

export default defineConfig({
  worker: {
    name: "hme-bridge",
    compatibilityDate: "2025-08-23",
    entrypoint: "build/worker/shim.mjs",
    env: {
      /*
       * NOTE: KV namespaceはTerraformで作成するため、IDには次のコマンドの値を記載する
       *       `mise run tf output -raw kv_namespace_id`
       *       `cf dev`ではこのIDを使わず、ローカルのKVを使う
       */
      HME_BRIDGE_CREDS: bindings.kv({
        id: "dummy-id-for-local-testing",
      }),
      ADMIN_TOKEN: bindings.secret(),
    },
  },
});
