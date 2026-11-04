# HME Bridge for Cloudflare Workers

This project acts as a bridge between Bitwarden's SimpleLogin integration and Apple's iCloud Hide My Email (HME) service,
running on the Cloudflare Workers serverless platform.

## Public Instance

For those who wish to use this service without setting up their own deployment,
a public instance is available for general use.

- **URL:** `https://hme-bridge-9hjgiu3hy.meru.workers.dev`

To use it, simply follow the instructions for **`Method 1: Direct Cookie Authentication`**,
and use the URL above for the **Self-host server URL** field in Bitwarden.

> [!WARNING]
> **Disclaimer:** Please be aware that when using the public instance,
> your iCloud cookie data is passed through this third-party server.
> While this instance is configured not to log or store your cookies,
> **self-hosting is strongly recommended for maximum security**.
> This service is provided as-is without any guarantee of uptime or long-term availability.

## How to Deploy

The infrastructure (the Worker, the KV namespace, the custom domain, and the R2 bucket for the Terraform state)
is managed with Terraform in `terraform/`.
The Worker code is built and deployed with the [Cloudflare CLI (`cf`)](https://developers.cloudflare.com/cf/).

### Prerequisites

1. **Install the tools:**
   Install the tools with [mise](https://mise.jdx.dev), then install the packages.

    ```bash
    mise install
    bun install
    ```

2. **Set the environment variables:**

   | Variable | Description |
   | --- | --- |
   | `AWS_ACCESS_KEY_ID` | Access key ID of an R2 API token (for the S3 backend) |
   | `AWS_SECRET_ACCESS_KEY` | Secret access key of an R2 API token (for the S3 backend) |
   | `CLOUDFLARE_API_TOKEN` | API token for the Cloudflare Terraform provider, `cf`, and Wrangler |
   | `TF_VAR_github_app_private_key` | Private key (PEM) of the GitHub App that CI uses for the GitHub Terraform provider |

   The GitHub Terraform provider uses the token in the `GITHUB_TOKEN` environment variable,
   or the token of `gh auth token` if it is not set.

### Initial Setup

1. **Create the R2 bucket for the Terraform state:**
   The bucket is managed by the same Terraform configuration.
   Until the bucket exists, create a local state, then migrate it to the bucket.

    1. Create `terraform/backend_override.tf` with the following content.

        ```hcl
        terraform {
          backend "local" {}
        }
        ```

    2. Create the bucket.

        ```bash
        mise run tf init
        mise run tf apply -target=cloudflare_r2_bucket.tfstate
        ```

    3. Delete `terraform/backend_override.tf`.
    4. Migrate the state to the bucket.

        ```bash
        mise run tf init -migrate-state
        ```

2. **Create the infrastructure:**
   Set `TF_VAR_cloudflare_api_token_read_write` to register the API token that CI uses for `terraform apply`.
   See [CI](#ci) for the token.

    ```bash
    mise run tf apply
    ```

3. **Set the KV namespace ID:**
   Replace the `id` of `HME_BRIDGE_CREDS` in `cloudflare.config.ts` with the output of the following command.

    ```bash
    mise run tf output -raw kv_namespace_id
    ```

### Build and Deploy

Deploy the Worker.

```bash
cf deploy
```

To set the admin token (`ADMIN_TOKEN`), use Wrangler, because `cf` cannot set a single secret yet.

```bash
bunx wrangler secret put ADMIN_TOKEN --name hme-bridge
```

### CI

Pull requests to `master` run `terraform plan`, and the plan is commented on the pull request.
Pushes to `master` run `terraform apply` with `.github/workflows/terraform-apply.yaml`.

Terraform creates the GitHub environments (`terraform-plan` and `terraform-apply`) and their secrets.
The API token for `terraform plan` is created by Terraform.
The API token for `terraform apply` is created on the Cloudflare dashboard,
because an API token created with an API token cannot have the `Account API Tokens Write` permission.
The token for `terraform apply` also needs permission to read and write the R2 bucket for the Terraform state,
because the workflow creates the credentials for the S3 backend from this token.
Terraform adds `[managed by terraform] hme_bridge/` to the names of the API tokens it creates.
Do not add `[managed by terraform]` to the name of the API token created on the dashboard.

CI runs the GitHub Terraform provider with a token of the GitHub App (the Client ID in the `UPDATE_CLIENT_ID` variable).
Install the GitHub App on this repository with the following repository permissions.

| Permission | Access | Used for |
| --- | --- | --- |
| Actions | Read-only | Reading the environments and the deployment branch policy |
| Administration | Read and write | Creating and updating the environments and the deployment branch policy |
| Environments | Read and write | The secrets of the environments |
| Secrets | Read and write | The secrets of the repository |
| Variables | Read and write | The variables of the repository |

CI does not set `TF_VAR_cloudflare_api_token_read_write`, so Terraform ignores changes to the registered secret.
To update the secret, set the new value to `TF_VAR_cloudflare_api_token_read_write` and apply it locally.

```bash
mise run tf apply -replace='github_actions_environment_secret.terraform_apply_cloudflare_api_token'
```

## Authentication Methods

This bridge supports two authentication methods:

1. **Direct Cookie Authentication (Legacy):** Suitable for clients like Bitwarden that only support a single API key field.
   You pass the iCloud cookie JSON directly in the `authentication` header.
2. **Centralized Token Authentication (Recommended):** A more secure and flexible method using a KV store to manage credentials.
   Clients authenticate using a short-lived token.
   This is ideal for multi-client or multi-account setups and is fully compatible with Bitwarden.

---

## Method 1: Direct Cookie Authentication (for Bitwarden)

This is the simplest method for Bitwarden users.

### How to Configure Bitwarden

1. Go to **Generator** -> **Username**.
2. Select **Forwarded email alias**.
3. For **Service**, select **SimpleLogin**.
4. For **Email domain**, enter your Cloudflare Worker's URL
   (e.g., `https://hme-bridge.your-username.workers.dev`).
   **Note:** Make sure to include `https://` at the beginning, and do **not** add a trailing `/`.
5. For **API Key**, paste your iCloud Cookie JSON here. See the next section for instructions on how to get it.

### How to get the API Key (iCloud Cookies)

To authenticate with iCloud, you must provide three essential cookies from your browser session.

1. Install a cookie editor extension that can export in **JSON format**. We recommend **Get cookies.txt LOCALLY**.
    - [Source Code](https://github.com/kairi003/Get-cookies.txt-LOCALLY)
    - [Chrome](https://chromewebstore.google.com/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc)
    - [Firefox Link](https://addons.mozilla.org/en-US/firefox/addon/get-cookies-txt-locally/)
2. Log in to [icloud.com](https://www.icloud.com/).
3. Open the extension and export cookies for the current site as **JSON**.
4. Open the exported JSON file/text.
5. Find the cookie objects corresponding to the following three `name`s:
    - `X-APPLE-DS-WEB-SESSION-TOKEN`
    - `X-APPLE-WEBAUTH-TOKEN`
    - `X-APPLE-WEBAUTH-USER`
6. You can simply copy and paste the entire exported JSON directly into Bitwarden —
   the server-side parser will automatically extract the required tokens.
   However, if you prefer a stricter setup, create a new JSON array containing **only these three cookie objects**.
7. Paste the resulting JSON array (or the full JSON if using the simple method) into the API Key field in Bitwarden.

**Example API Key format:**

```json
[
  {
    "domain": ".icloud.com",
    "name": "X-APPLE-DS-WEB-SESSION-TOKEN",
    "value": "AQFq...",
    "...": "..."
  },
  {
    "domain": ".icloud.com",
    "name": "X-APPLE-WEBAUTH-TOKEN",
    "value": "v=2:t=...",
    "...": "..."
  },
  {
    "domain": ".icloud.com",
    "name": "X-APPLE-WEBAUTH-USER",
    "value": "v=1:s=1...",
    "...": "..."
  }
]
```

---

## Method 2: Centralized Token Authentication (Recommended)

This method is more secure and flexible, allowing you to manage multiple accounts or clients.
It is **fully compatible with Bitwarden**.

### How it Works for Bitwarden Users

Instead of pasting your full iCloud cookie data into Bitwarden's API Key field,
you first store the cookie data in the bridge's secure KV store and generate a simple token.
Then, you just use that short token as your API Key in Bitwarden.

This has two main benefits:

- **Enhanced Security:** Your sensitive iCloud cookie is not stored in the Bitwarden client.
- **Simplified Management:** If your cookie expires, you only need to update it in one place (the KV store),
  and all your clients (including Bitwarden) will work again without any changes.

### 1. Configure KV Namespace and Admin Token

The KV namespace (`HME_BRIDGE_CREDS`) for storing credentials and the admin token (`ADMIN_TOKEN`) for managing them
are set up in [How to Deploy](#how-to-deploy).
Choose a strong, random string for the admin token.

For local testing with `cf dev`, a local KV namespace is used, and the admin token is read from `.dev.vars`.

```bash
echo 'ADMIN_TOKEN="your_super_secret_admin_token"' > .dev.vars
```

### 2. Manage Credentials via Admin API

A full set of CRUD (Create, Read, Update, Delete) endpoints are provided to manage your credentials.
All requests must include the `X-Admin-Token` header.

#### A. Create a New Credential

This endpoint will add a new credential to the store and return it with a randomly generated token.

- **Endpoint:** `POST /admin/credentials`
- **Body:** A JSON object with a `label` (a friendly name for the credential) and the `cookie` data (as a JSON array).

**Example `curl` command:**
(Assumes your cookie data is in a file named `cookie.json`)

```bash
jq -n --arg label "My Personal Account" --argjson cookie "$(cat cookie.json)" \
  '{"label": $label, "cookie": $cookie}' | \
  curl -X POST https://your-worker.workers.dev/admin/credentials \
    -H "X-Admin-Token: your_super_secret_admin_token" \
    -H "Content-Type: application/json" \
    -d @-
```

**Successful Response:**
You will get a JSON response containing the new credential, including the generated `token`.
Use this token in your client (e.g., Bitwarden API Key).

```json
{
  "label": "My Personal Account",
  "token": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4",
  "cookie": "[...]"
}
```

#### B. List All Credentials

- **Endpoint:** `GET /admin/credentials`

**Example `curl` command:**

```bash
curl https://your-worker.workers.dev/admin/credentials \
  -H "X-Admin-Token: your_super_secret_admin_token"
```

**Successful Response:** An array of all stored credential objects.

#### C. Update a Credential

- **Endpoint:** `PUT /admin/credentials/:token`
- **Body:** A JSON object with the updated `label` and `cookie`.

**Example `curl` command:**
(Updates the credential with the token `a1b2c3d4...`, using cookie data from `new_cookie.json`)

```bash
jq -n --arg label "My Updated Account" --argjson cookie "$(cat new_cookie.json)" \
  '{"label": $label, "cookie": $cookie}' | \
  curl -X PUT https://your-worker.workers.dev/admin/credentials/a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4 \
    -H "X-Admin-Token: your_super_secret_admin_token" \
    -H "Content-Type: application/json" \
    -d @-
```

#### D. Delete a Credential

- **Endpoint:** `DELETE /admin/credentials/:token`

**Example `curl` command:**

```bash
curl -X DELETE https://your-worker.workers.dev/admin/credentials/a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4 \
  -H "X-Admin-Token: your_super_secret_admin_token"
```

**Successful Response:** A simple text message like `Credential deleted`.

### 3. Client Configuration

#### For Bitwarden Users

After creating a credential and getting a token from the `POST /admin/credentials` endpoint,
simply go to Bitwarden's generator settings and paste the returned **token** into the **API Key** field.
The bridge will automatically detect that you are using a token and retrieve the corresponding cookie from the KV store.

#### For Custom Clients

Custom clients can use the token in two ways:

1. **Via `authentication` header (like Bitwarden):**

    ```text
    authentication: <your_token>
    ```

2. **Via `Authorization` header (Standard method):**

    ```text
    Authorization: Bearer <your_token>
    ```

This provides flexibility for different types of clients.

## LICENSE

[MIT](LICENSE)
