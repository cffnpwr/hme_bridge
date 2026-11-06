use std::collections::HashMap;

use serde::Deserialize;
use url::Url;
use wasm_bindgen::JsValue;
use worker::{Fetch, Headers, Method, Request, RequestInit};

#[derive(Debug, Deserialize)]
struct WebService {
    url: Option<String>,
}

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
struct ValidateResponse {
    webservices: HashMap<String, WebService>,
}

#[derive(Debug, Deserialize)]
struct GenerateHmeResult {
    hme: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HmeEmail {
    pub forward_to_email: Option<String>,
    pub hme: String,
    pub is_active: bool,
    pub label: String,
    pub note: String,
    pub create_timestamp: i64,
}

#[derive(Debug, Deserialize)]
struct ReserveHmeResult {
    hme: HmeEmail,
}

#[derive(Debug, Deserialize)]
struct PremiumMailSettingsResponse<T> {
    success: bool,
    result: T,
    error: Option<serde_json::Value>,
}

#[derive(Clone, Copy)]
enum ApiStage {
    Validate,
    Generate,
    Reserve,
}

struct ApiResponse<T> {
    status: u16,
    body: String,
    json: T,
}

impl std::fmt::Display for ApiStage {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let name = match self {
            Self::Validate => "validate",
            Self::Generate => "generate",
            Self::Reserve => "reserve",
        };
        f.write_str(name)
    }
}

fn log_failure(stage: ApiStage, status: u16, body: &str, reason: &str) {
    log::error!(
        "[icloud:{}] {} (status: {}, body: {})",
        stage,
        reason,
        status,
        body
    );
}

async fn post<T: for<'de> Deserialize<'de>>(
    stage: ApiStage,
    url: &str,
    cookie_header: &str,
    body: Option<serde_json::Value>,
) -> Result<ApiResponse<T>, worker::Error> {
    let headers = Headers::new();
    headers.set("Cookie", cookie_header)?;
    headers.set("Content-Type", "application/json")?;
    headers.set("Origin", "https://www.icloud.com")?;
    headers.set("Referer", "https://www.icloud.com/")?;
    headers.set(
        "User-Agent",
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36",
    )?;

    let mut init = RequestInit::new();
    init.with_method(Method::Post).with_headers(headers);
    if let Some(body_value) = body {
        init.with_body(Some(JsValue::from_str(
            &serde_json::to_string(&body_value).unwrap(),
        )));
    }

    let req = Request::new_with_init(url, &init)?;
    let mut res = Fetch::Request(req).send().await.map_err(|e| {
        log::error!("[icloud:{}] request failed: {}", stage, e);
        e
    })?;
    let status = res.status_code();
    let text = res.text().await.map_err(|e| {
        log::error!(
            "[icloud:{}] failed to read response body (status: {}): {}",
            stage,
            status,
            e
        );
        e
    })?;
    let json: T = serde_json::from_str(&text).map_err(|e| {
        log_failure(
            stage,
            status,
            &text,
            &format!("failed to parse response: {}", e),
        );
        worker::Error::from(e)
    })?;
    log::info!("[icloud:{}] status: {}", stage, status);
    Ok(ApiResponse {
        status,
        body: text,
        json,
    })
}

pub async fn generate_and_reserve_hme(
    cookie_header: &str,
    label: &str,
    note: &str,
) -> Result<HmeEmail, worker::Error> {
    let mut url = Url::parse("https://setup.icloud.com/setup/ws/1/validate").unwrap();
    url.query_pairs_mut()
        .append_pair("clientBuildNumber", "2420Hotfix12")
        .append_pair("clientMasteringNumber", "2420Hotfix12")
        .append_pair("clientId", "")
        .append_pair("dsid", "");

    let validate_res: ApiResponse<ValidateResponse> =
        post(ApiStage::Validate, url.as_str(), cookie_header, None).await?;

    let base_url = validate_res
        .json
        .webservices
        .get("premiummailsettings")
        .and_then(|ws| ws.url.as_ref())
        .ok_or_else(|| {
            log_failure(
                ApiStage::Validate,
                validate_res.status,
                &validate_res.body,
                "premiummailsettings URL not found",
            );
            worker::Error::from("premiummailsettings URL not found")
        })?;

    // Generate HME
    let generate_url = format!("{}/v1/hme/generate", base_url);
    let generate_res: ApiResponse<PremiumMailSettingsResponse<GenerateHmeResult>> = post(
        ApiStage::Generate,
        &generate_url,
        cookie_header,
        Some(serde_json::json!({ "langCode": "en-us" })),
    )
    .await?;

    if !generate_res.json.success {
        log_failure(
            ApiStage::Generate,
            generate_res.status,
            &generate_res.body,
            "success is false",
        );
        return Err(worker::Error::from(format!(
            "Failed to generate HME: {:?}",
            generate_res.json.error
        )));
    }
    let hme = generate_res.json.result.hme;

    // Reserve HME
    let reserve_url = format!("{}/v1/hme/reserve", base_url);
    let reserve_body = serde_json::json!({
        "hme": hme,
        "label": label,
        "note": note
    });
    let reserve_res: ApiResponse<PremiumMailSettingsResponse<ReserveHmeResult>> = post(
        ApiStage::Reserve,
        &reserve_url,
        cookie_header,
        Some(reserve_body),
    )
    .await?;

    if !reserve_res.json.success {
        log_failure(
            ApiStage::Reserve,
            reserve_res.status,
            &reserve_res.body,
            "success is false",
        );
        return Err(worker::Error::from(format!(
            "Failed to reserve HME: {:?}",
            reserve_res.json.error
        )));
    }

    Ok(reserve_res.json.result.hme)
}
