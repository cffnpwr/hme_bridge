import cffnpwrConfig from "@cffnpwr/eslint-config";
import tsEslintParser from "@typescript-eslint/parser";
import { defineConfig, globalIgnores } from "eslint/config";
import globals from "globals";

const files = ["**/*.ts"];

export default defineConfig([
  globalIgnores(["build/", "target/", ".cloudflare/"]),
  {
    files,
    languageOptions: {
      globals: {
        ...globals.node,
      },
      parser: tsEslintParser,
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
  },
  {
    files,
    extends: cffnpwrConfig(),
  },
]);
