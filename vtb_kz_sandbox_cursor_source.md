# VTB KZ Sandbox eCommerce Integration Compact Reference

Status: verified offline reference. The high-level shell was extracted from the public sandbox documentation at https://sandbox.vtb-bank.kz/#ecommerce; the concrete request/response schemas in the "VERIFIED API CONTRACT" sections below were extracted from the live REST documentation at https://sandbox.vtb-bank.kz/ru/integration/api/rest.html (RBS / "rbsuat" payment platform). This file is sufficient to implement a single-stage hosted-payment-page (redirect) integration end-to-end.

## Scope discovered on-site
- eCommerce documentation is organized into these sections: simple-integration, advanced-integration, additional-features, reference, api-reference.
- The documentation site exposes an API mode switcher with API V1 and API V2.
- The platform is the classic RBS gateway (same family as Sberbank/Alfa/etc.), so endpoint and parameter names follow the well-known `*.do` REST contract.

## Integration path from scratch
1. Obtain merchant API credentials for the sandbox (`userName` + `password`, the `-api` login). Target API V1 REST.
2. Create an order on the payment gateway with `register.do`, then redirect the customer to the hosted payment page returned by the gateway as `formUrl`.
3. After payment, handle browser return via `returnUrl` (success) or `failUrl` (failure). The gateway appends the gateway order id to that URL.
4. Track final order state from your backend with `getOrderStatusExtended.do`; never trust the browser redirect alone.
5. Optionally also handle asynchronous gateway callbacks (webhooks) for robustness.
6. Add optional operations only after the base flow works: preauth/deposit, reverse, refund, saved cards/bindings, 3-D Secure checks, Apple Pay / Google Pay.

---

# VERIFIED API CONTRACT (sandbox)

## Base URLs
- TEST / sandbox: `https://vtbkz.rbsuat.com/payment/rest/`
- PRODUCTION:     `https://payment.vtb.kz/payment/rest/`

All REST endpoints below are relative to that base (e.g. `…/payment/rest/register.do`).

## Authentication
Two mutually exclusive schemes, sent as ordinary form fields in the request body:
- `userName` (String[1..50]) + `password` (String[1..30]) — the merchant API account, OR
- `token` (String[1..256]) — a pre-issued open token (then do NOT send `userName`/`password`).

Request signing (`X-Hash` / `X-Signature` headers) is only required for P2P/AFT/OCT operations — NOT needed for a normal eCommerce card payment.

## Transport & success detection
- All calls are HTTP `POST` with header `Content-Type: application/x-www-form-urlencoded`.
- HTTP `200` does NOT imply payment success — you must parse the JSON body.
- Request processing succeeded when `errorCode == "0"` (or `errorCode` is absent), or when `success == true`. If both are present, `success` wins.
- HTTP `400` internal error, `404` bad URL, `429` rate-limited/overloaded, `500/502` gateway-side failure.

## Amount & currency
- `amount` is an **Integer in the minor currency unit** (for KZT: tiyin; 1 KZT = 100 tiyin). Example: 2000 = 20.00 KZT.
- `currency` is the **ISO 4217 numeric** code, digits only. **KZT = 398** (RUB = 643 in some doc examples).
- For this project: **1 OWK = 1 KZT**, so `amount = creditsOWK * 100` tiyin, `currency = 398`.

---

## `register.do` — register a single-stage order

POST `…/payment/rest/register.do`, `application/x-www-form-urlencoded`.

### Request parameters (subset used here; full list has many optional 3DS/cart fields)
| Required | Name | Type | Notes |
| --- | --- | --- | --- |
| yes* | `userName` | String[1..50] | API login (*or use `token`). |
| yes* | `password` | String[1..30] | API password (*or use `token`). |
| —    | `token` | String[1..256] | Alternative to userName/password. |
| yes  | `orderNumber` | String[1..36] | Merchant-side unique order id. Must be unique per order. |
| yes  | `amount` | Integer[0..12] | Payment amount in minor units (tiyin). |
| —    | `currency` | String[3] | ISO 4217 numeric (398 = KZT). Defaults to shop setting if omitted. |
| —    | `returnUrl` | String[1..512] | Full absolute URL (incl. scheme) the payer returns to on success. |
| —    | `failUrl` | String[1..512] | Full absolute URL for the failure/cancel path. |
| —    | `dynamicCallbackUrl` | String[1..512] | Per-order URL for payment callbacks (deposited/approved/reversed/refunded/declined). Must be enabled for the merchant. |
| —    | `description` | String[1..598] | Free-form order description. Do NOT put PAN/PII here (never masked). |
| —    | `language` | String[2] | ISO 639-1: `ru`, `en`, `hy`, `az`. |
| —    | `clientId` | String[0..255] | Merchant customer id, required if you create card bindings. |
| —    | `email` | String[1..40] | Shown on payment page; validated at pay time, not at register. |
| —    | `sessionTimeoutSecs` | Integer[1..9] | Order lifetime in seconds. Default 1200 (20 min) if unset. Ignored if `expirationDate` is sent. |
| —    | `expirationDate` | String[19] | `yyyy-MM-ddTHH:mm:ss`. Overrides `sessionTimeoutSecs`. |
| —    | `jsonParams` | Object(JSON string) | Extra attributes, e.g. `{"backToShopUrl":"…"}`. |
| —    | `features` | String | e.g. `FORCE_SSL`, `FORCE_TDS`. Repeat the param for multiple values. |

> IMPORTANT about `returnUrl`/`failUrl`: must be a complete URL including protocol (`https://…`), otherwise the payer is redirected to a gateway default page. After authentication the gateway redirects to `returnUrl` with the gateway order id appended (param `orderId`); on failure to `failUrl` (or `returnUrl` if `failUrl` was omitted), also with the order id appended.

### Response parameters
| Name | Type | Notes |
| --- | --- | --- |
| `orderId` | String[1..36] | Gateway order id (a.k.a. `mdOrder`). Unique within the gateway. Persist it. |
| `formUrl` | String[1..512] | Hosted payment page URL to redirect the payer to. Absent on error. |
| `errorCode` | String[1..2] | `0` = ok; `1..99` = error (see `errorMessage`). May be absent on success. |
| `errorMessage` | String[1..512] | Human-readable error; localized by `language`. Do not branch on its text. |

### Example request
```
curl --request POST \
  --url https://vtbkz.rbsuat.com/payment/rest/register.do \
  --header 'content-type: application/x-www-form-urlencoded' \
  --data amount=123456 \
  --data currency=398 \
  --data userName=test_user \
  --data password=test_user_password \
  --data orderNumber=1234567890ABCDEF \
  --data returnUrl=https://mybestmerchantreturnurl.com \
  --data failUrl=https://mybestmerchantfailurl.com \
  --data description=my_first_order \
  --data language=ru
```

### Example success response
```json
{
  "orderId": "01491d0b-c848-7dd6-a20d-e96900a7d8c0",
  "formUrl": "https://vtbkz.rbsuat.com/payment/merchants/ecom/payment_en.html?mdOrder=01491d0b-c848-7dd6-a20d-e96900a7d8c0"
}
```

### Example error response
```json
{ "errorCode": "1", "errorMessage": "Order number is duplicated, order with given order number is processed already" }
```

---

## `getOrderStatusExtended.do` — authoritative order status

POST `…/payment/rest/getOrderStatusExtended.do`, `application/x-www-form-urlencoded`.

### Request parameters
| Required | Name | Type | Notes |
| --- | --- | --- | --- |
| yes* | `userName`/`password` or `token` | — | Same auth as register. |
| one of | `orderId` | String[1..36] | Gateway order id from `register.do`. Preferred. |
| one of | `orderNumber` | String[1..36] | Merchant order id (alternative to `orderId`). |
| —    | `language` | String[2] | ru/en/hy/az. |

### Key response parameters
| Name | Type | Notes |
| --- | --- | --- |
| `errorCode` | String[1..2] | `0` = request processed; otherwise see `errorMessage`. May be absent. |
| `errorMessage` | String[1..512] | Localized request-level error. |
| `orderNumber` | String[1..36] | Your merchant order id. |
| `orderStatus` | Integer | The order lifecycle state — SEE TABLE BELOW. Absent if order not found. |
| `actionCode` | String/Integer | Processing bank response code (numeric). |
| `actionCodeDescription` | String[1..512] | Description of `actionCode`. |
| `amount` | Integer[0..12] | Amount in minor units. |
| `currency` | String[3] | ISO 4217 numeric. |
| `date` | Integer | Order registration time, Unix epoch ms. |
| `depositedDate` | Integer | Payment/capture time, Unix epoch ms (status set version 10+). |
| `attributes[]` | Array | Contains `{ "name":"mdOrder", "value":"<gateway order id>" }`. |
| `cardAuthInfo` | Object | `maskedPan`, `expiration`, `cardholderName`, `approvalCode`, … |
| `paymentAmountInfo` | Object | `paymentState` (e.g. `DEPOSITED`), `approvedAmount`, `depositedAmount`, `refundedAmount`. |

### `orderStatus` values (authoritative)
- `0` — registered, not paid
- `1` — pre-authorized / amount held, not yet captured (two-stage)
- `2` — authorized AND captured (fully paid; the success state for single-stage)
- `3` — authorization reversed (canceled)
- `4` — refunded (a refund was performed)
- `5` — authorization initiated through issuer ACS (3-D Secure in progress)
- `6` — authorization declined
- `7` — awaiting payment
- `8` — intermediate completion (multi-step partial capture)

> Paid check: the order is considered paid only if `orderStatus` is `1` or `2`. For a single-stage payment, success is `orderStatus == 2`. `6` = declined/failed.

### Example request
```
curl --request POST \
  --url https://vtbkz.rbsuat.com/payment/rest/getOrderStatusExtended.do \
  --header 'content-type: application/x-www-form-urlencoded' \
  --data userName=test_user \
  --data password=test_user_password \
  --data orderId=01491d0b-c848-7dd6-a20d-e96900a7d8c0 \
  --data language=ru
```

### Example response (paid)
```json
{
  "errorCode": "0",
  "errorMessage": "Success",
  "orderNumber": "7005",
  "orderStatus": 2,
  "actionCode": 0,
  "actionCodeDescription": "",
  "amount": 2000,
  "currency": "398",
  "date": 1617972915659,
  "attributes": [ { "name": "mdOrder", "value": "01491d0b-c848-7dd6-a20d-e96900a7d8c0" } ],
  "cardAuthInfo": { "maskedPan": "411111**1111", "expiration": "203412", "cardholderName": "TEST CARDHOLDER", "approvalCode": "12345678" },
  "paymentAmountInfo": { "paymentState": "DEPOSITED", "approvedAmount": 2000, "depositedAmount": 2000, "refundedAmount": 0 }
}
```

---

## Browser return after payment
- On success the gateway redirects the payer to `returnUrl` with the gateway order id appended (param `orderId`), e.g. `https://merchant/return?orderId=85eb9a84-…`.
- On failure it redirects to `failUrl` (or `returnUrl` if `failUrl` was omitted), also with the order id appended.
- The redirect can be lost (closed browser, dropped connection), so the merchant MUST confirm via `getOrderStatusExtended.do` and/or callbacks — the redirect is only a hint.

## Asynchronous callbacks (webhooks) — optional but recommended
- Configured per-merchant; per-order override via `dynamicCallbackUrl`. Supports GET (query params) and POST (form body).
- Core params: `mdOrder` (gateway order id), `orderNumber` (merchant order id), `operation`, `status` (`1` success / `0` failure), and optionally `checksum` (+ `sign_alias`), `amount`, `callbackCreationDate`.
- `operation` values relevant to payment status: `approved` (hold placed), `deposited` (captured), `reversed`, `refunded`, `declinedByTimeout`, `declinedCardPresent`, plus binding events.
- Payment success on a single-stage flow: `operation == "deposited" && status == "1"`.
- Respond `200 OK` to acknowledge; otherwise the gateway retries every 30s up to 3 times.

### Checksum verification (when checksum callbacks are enabled)
1. Remove `checksum` and `sign_alias` from the received params; keep the rest.
2. Sort the remaining params by name in ascending alphabetical order.
3. Build the string `name1;value1;name2;value2;…;nameN;valueN;` (trailing `;` after every pair). Example: `amount;123456;mdOrder;3ff6962a-…;operation;deposited;orderNumber;10747;status;1;`.
4. Symmetric: compute `HMAC-SHA256(string, sharedKey)`. Asymmetric: verify with the gateway public key.
5. Uppercase the resulting hex and compare to the received `checksum` (constant-time compare). Equal ⇒ authentic.
- Once a checksum callback is verified you do NOT strictly need `getOrderStatusExtended` (the callback carries the status), but re-verifying server-side is still safest.

---

## Recommended backend architecture (as implemented in this repo)
- Never call the gateway from the browser; credentials live only on the backend.
- Frontend asks the backend to create a payment; backend calls `register.do` and returns only `{ paymentId, formUrl }`.
- Frontend redirects to `formUrl`.
- Gateway returns the payer to the backend-built `returnUrl`/`failUrl` (which point at the SPA payment-return route carrying our local `paymentId`).
- The SPA return route asks the backend to "sync" the payment; the backend calls `getOrderStatusExtended.do`, updates the local state machine, and idempotently grants OWK credits on `orderStatus ∈ {1,2}`.
- A backend callback endpoint independently verifies and grants credits, so success is captured even if the browser never returns.

## Data model stored locally (this repo: `payments` + `payment_events`)
- `uid` (local payment id, used as `orderNumber`), `user_uid`
- `order_number` (sent to gateway), `gateway_order_id` (`orderId`/`mdOrder`)
- `credits` (OWK to grant), `amount_minor` (tiyin), `currency` (398)
- `status` (state machine: created → registered → pending → paid / failed / canceled / refunded)
- `form_url`, `return_url`, `fail_url`
- `order_status` (last numeric gateway status), `action_code`, `error_code`, `error_message`
- `credited_at` (idempotency guard — credits granted exactly once)
- `raw_last_gateway_response` (redacted JSON), `created_at` / `updated_at` / `expires_at`
- `payment_events`: append-only per-step audit (type, message, redacted detail, created_at) mirrored to stdout logs.

## Security and correctness notes
- Amount is always minor units (tiyin) — multiply OWK by 100.
- Treat the browser redirect as advisory; confirm via `getOrderStatusExtended.do` and/or verified callback.
- Never expose `userName`/`password`/`token` to the browser or in logs (redact them).
- Idempotent credit granting: a single conditional `UPDATE … WHERE credited_at IS NULL` decides the unique winner; both the return-sync and callback paths funnel through it.
- `orderNumber` must be unique per order (duplicates are rejected with errorCode 1).
- Validate that `returnUrl`/`failUrl` belong to your own front-end origin.

## Remaining gaps to verify before PRODUCTION go-live
- Exact sandbox merchant credentials and whether your account is single- or two-stage by default (affects whether success is `orderStatus 2` only, or also `1`).
- Whether checksum callbacks are enabled for your merchant and the symmetric key / public key to use.
- The set of test cards provided for the sandbox.
- Whether `getOrderStatusExtended` version configured for your merchant returns `depositedDate`/`paymentAmountInfo` (used only for richer logging here).
- Apple Pay / Google Pay onboarding and binding/card-storage prerequisites (out of scope for the base top-up flow).
