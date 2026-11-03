import { bindings, defineConfig } from "cf/config";

export default defineConfig({
	worker: {
		name: "hme-bridge",
		compatibilityDate: "2025-08-23",
		entrypoint: "build/worker/shim.mjs",
		env: {
			// NOTE: KV namespaceはTerraformで作成するため、IDは`mise run tf output -raw kv_namespace_id`の値を記載する
			//       `cf dev`ではこのIDを使わず、ローカルのKVを使う
			HME_BRIDGE_CREDS: bindings.kv({
				id: "dummy-id-for-local-testing",
			}),
			ADMIN_TOKEN: bindings.secret(),
		},
	},
});
