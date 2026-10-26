# DOOM — Gemini Integration Specification (Phase 02)

**Status:** Implemented and verified in Milestone M05 (2026-10-25) and updated in IMPL-06. Verified against Google's official Gemini documentation (Interactions API `/v1beta/interactions`, default model `gemini-3.5-flash`, `store: false`, `stream: false`). Unit tests pass with `StubURLProtocol` mocks; live smoke test path available via Settings UI or `scripts/live-gemini-smoke-test.sh`.
**Phase 01 basis:**
- C-5: network only on user action; key in the `x-goog-api-key` header only; cancellable; model configurable in one place; tier privacy.
- C-6 / D-23: Keychain.
- D-13: logging.
- D-24: no telemetry.

**Decisions:** these are recorded in `TECHNICAL_DECISIONS.md` §C.

| Decision | Topic |
|---|---|
| P2-06 | API surface *(approved, Phase 03 §D.1)* |
| P2-07 | Default model *(approved, Phase 03 §D.1; availability verified in M05, GEMINI-29)* |
| P2-08 | System instruction *(approved, Phase 03 §D.1)* |
| P2-09 | Retry policy |
| P2-11 | Tier disclosure *(approved, Phase 03 §D.1)* |

> **Revalidation markers.** Items tagged **⟳ REVALIDATE** are model- or API-specific facts taken from Google's documentation on 2026-10-24. They must be re-checked against the live documentation, and against one live request (GEMINI-INT-01), at the start of milestone M05 (`IMPLEMENTATION_ROADMAP.md`).

---

## 1. Hard rules

1. **Exactly one HTTP request per activation, and per Retry click.** There are no automatic retries, no chained calls, and no follow-up calls (rewrite, classify, summarise or verify).
2. **The response is shown as received.** It is never sent to any model, including Gemini.
3. **No network activity at launch** or in the background. That includes model-list fetches, key validation pings, update checks and telemetry.
4. The API key is never placed in a URL, log, error value, UserDefaults, file, environment variable (app target) or crash annotation.
5. Only one request is in flight app-wide (`PRODUCT_BEHAVIOR.md` INV-1).

---

## 2. Exactly what data is sent, and when

**When:** only in `PRODUCT_BEHAVIOR.md` S-06, which happens after an activation (or Retry) with all prerequisites satisfied, including the one-time privacy acknowledgement.

| Data | Sent? | Where |
|---|---|---|
| Selected text (validated, trimmed, ≤ 20,000 characters) | **Yes** | Body `input` |
| Fixed system instruction (§3.3) | **Yes** | Body `system_instruction` |
| Model ID | **Yes** | Body `model` |
| Generation settings (`thinking_level`, `max_output_tokens`) | **Yes** | Body `generation_config` |
| `store: false`, `stream: false` | **Yes** | Body |
| API key | **Yes** | Header `x-goog-api-key` |
| Source app name, bundle ID, window title, URL, document name | **No** | — |
| Clipboard contents (other than the selection obtained through the fallback) | **No** | — |
| Earlier selections or responses (history, conversation) | **No** | — |
| User identity, device identifiers, locale, analytics | **No** | — |
| **Implicitly sent by the network stack** | IP address, TLS metadata, the default URLSession `User-Agent` (app name, version, CFNetwork/Darwin versions), and `Accept-Language` | Transport |

**Not used:**
- `previous_interaction_id`, `tools`, `background`, `response_format`, `safety_settings` (provider defaults apply), `labels`, `service_tier`, `webhook_config`;
- file and image inputs.

---

## 3. Request

### 3.1 API surface *(P2-06, approved; ⟳ REVALIDATE in M05)*

| Option | Endpoint | Status per Google docs (2026-10-24) | Choice |
|---|---|---|---|
| **Interactions API** | `POST https://generativelanguage.googleapis.com/v1beta/interactions` | GA (June 2026), "recommended for new projects". New models launch only on Interactions. | **Selected** |
| `generateContent` | `POST …/v1beta/models/{model}:generateContent` | "Legacy", still fully supported | Documented alternative |

**Rationale:**
- It is forward-compatible with new models.
- It has a typed error-code taxonomy (`code` strings).
- It has explicit storage control.

**Storage note:**
- Interactions **stores requests by default** (`store` defaults to true): 55 days on the paid tier, 1 day on the free tier.
- DOOM **always sends `store: false`**. DOOM doesn't use `previous_interaction_id` or background mode, both of which require storage, so nothing is lost.
- `store: false` controls retrieval storage only. It does not change Google's terms on how content is used, for example unpaid-tier improvement use (`SECURITY_AND_PRIVACY.md` §2.4).

### 3.2 HTTP

```
POST /v1beta/interactions HTTP/1.1
Host: generativelanguage.googleapis.com
Content-Type: application/json
Accept: application/json
x-goog-api-key: <key from Keychain>

{
  "model": "<modelID>",
  "input": "<selected text>",
  "system_instruction": "<SystemInstruction.v1>",
  "generation_config": {
    "thinking_level": "low",
    "max_output_tokens": 4096
  },
  "store": false,
  "stream": false
}
```

- The body is encoded with `JSONEncoder` from a `Codable` struct. String concatenation is never used, so escaping is always correct.
- `input` is the selected text **verbatim**, with no wrapper.
- `temperature` is **not sent**, so the model default applies. This avoids degrading 3.x models that are tuned for their default.
- `thinking_level: "low"` reduces latency. Supported on `gemini-3.5-flash` and `gemini-3.8-flash`.
- `max_output_tokens: 4096` bounds response size and cost.

### 3.3 Model configuration *(P2-07, approved; IMPL-06)*

| Item | Value |
|---|---|
| Default model | `gemini-3.5-flash`: stable, fully available on `/v1beta/interactions`, 1,048,576 input tokens, supports thinking levels (IMPL-06) |
| Faster or cheaper alternative | `gemini-3.5-flash-lite` (latency ~1.1s) |
| Not used | Aliases such as `gemini-flash-latest`. They change silently, which makes behaviour non-reproducible. |
| User override | Settings › Gemini › Model: a text field validated against `^[a-z0-9][a-z0-9.\-]{0,63}$` (E-CFG-01), with [Reset to default]. Stored in UserDefaults (non-secret). |
| Single place | `GeminiConfiguration.defaultModelID` (Core constant). The endpoint base URL is a constant in the client. |
| System instruction | `SystemInstruction.v1`: the exact text in `PRODUCT_BEHAVIOR.md` §4 (one constant). Changing it is a product decision. |

---

## 4. Transport

| Setting | Value | Why |
|---|---|---|
| Session | `URLSession(configuration: .ephemeral)`, one instance owned by `GeminiClient` | No disk cache, cookies or credential persistence |
| `urlCache` / `httpCookieStorage` / `urlCredentialStorage` | `nil` / `nil` / `nil`; `httpShouldSetCookies = false` | Defence in depth |
| `timeoutIntervalForRequest` | 60 s | Non-streaming responses arrive all at once after generation |
| `timeoutIntervalForResource` | 60 s | Hard cap that matches E-NET-03 |
| `waitsForConnectivity` | `false` | Fail fast offline (E-NET-01) |
| TLS | System default (ATS); **no certificate pinning** | Google rotates certificates, and pinning would cause outages. Platform trust is adequate for this threat model |
| Response size cap | 2 MB of body | Larger → `.malformedResponse` |
| Redirects | Not followed for POST (delegate returns `nil`) | The key header must never go to an unexpected host |

---

## 5. Concurrency and cancellation

- `GeminiClient` is a `Sendable` struct with an `async throws(GenerationError)` method. It has no shared mutable state.
- Concurrency limit 1 and deduplication are enforced by `AssistantController`, the single-flight `@MainActor` state machine. Any further activation while busy is ignored, and Retry is disabled while requesting.
- **Cancellation:** the flow's `Task` is cancelled. `URLSession.data(for:)` honours task cancellation and throws `URLError.cancelled`, which maps to `GenerationError.cancelled` and is never shown.
- **Late completion:** a response that arrives after cancellation is dropped. The controller compares a flow token, a UUID generated per flow and kept in memory only, before applying any result.

---

## 6. Response parsing (⟳ REVALIDATE shapes)

**Documented example shape (non-streaming, success):**

```json
{ "id": "...", "model": "gemini-3.6-flash", "object": "interaction", "status": "completed",
  "steps": [ { "type": "model_output", "content": [ { "type": "text", "text": "..." } ] } ],
  "usage": { "total_input_tokens": 7, "total_output_tokens": 20, "total_thought_tokens": 22, "total_tokens": 49 } }
```

**Parsing rules:**
1. Decode leniently (`Decodable` that ignores unknown fields). The only required fields are `status` and `steps`, and an empty `steps` array is allowed.
2. **Output text** = the `text` of every `content` item with `type == "text"` in the **last** step whose `type == "model_output"`, joined in order. This matches the documented SDK `output_text` semantics.
   - Steps of other types (for example thoughts) are **ignored**, never displayed and never logged.
3. **Status handling:**

   | `status` | Behaviour |
   |---|---|
   | `completed` | Text non-empty after trim → success. Empty → E-GEN-02. |
   | `incomplete` *(assumed value)* | Text non-empty → success with `isTruncated = true` (N-05). Empty → E-GEN-02. |
   | `failed` *(assumed value)* | If `error.code` is present, map it by §7. Otherwise E-GEN-03. |
   | anything else | Text present → success, and log `status.unknown`. Otherwise E-GEN-03. |

4. A `usage` field (token counts) is decoded when present and logged as counts only.
5. A body that isn't JSON, lacks `steps`, or exceeds 2 MB → `.malformedResponse` (E-GEN-03).
6. The provider's `error.message` is **never** shown or logged, because it may echo input. Only `code` is used.

**Rendering** happens in Features: inline Markdown (`AttributedString(markdown:options: .inlineOnlyPreservingWhitespace)`). Link attributes are removed or made non-interactive, and parse failure falls back to plain text (`UI_SPECIFICATION.md` §3.6).

---

## 7. Error mapping (Interactions error JSON: `{"error":{"code":"…","message":"…"}}`)

| HTTP | `error.code` | `GenerationError` | User msg | Retryable |
|---|---|---|---|---|
| — | (URLError `.notConnectedToInternet`) | `.offline` | E-NET-01 | Yes |
| — | (URLError `.timedOut`) | `.timedOut` | E-NET-03 | Yes |
| — | (other URLError: DNS, TLS, connection lost) | `.transport(code: Int)` | E-NET-02 | Yes |
| — | (URLError `.cancelled`) | `.cancelled` | — | — |
| 400 | `invalid_request`, `parameter_unknown` | `.badRequest(code)` | E-API-09 | No |
| 400 | `failed_precondition` | `.unavailableForAccount` | E-API-07 | No |
| 401 | `authentication` | `.invalidAPIKey` | E-API-01 | No |
| 402 | `payment_required` | `.paymentRequired` | E-API-05 | No |
| 403 | `permission_denied` | `.permissionDenied` | E-API-02 | No |
| 404 | `model_not_found`, `not_found` | `.modelNotFound` | E-API-06 | No |
| 429 | `rate_limit_exceeded`, `too_many_requests` | `.rateLimited(retryAfter:)` | E-API-03 | After cooldown |
| 429 | `quota_exceeded` | `.quotaExceeded` | E-API-04 | No |
| 499 | `cancelled` | `.cancelled` | — | — |
| 500 | `api_error` | `.server(status)` | E-API-08 | Yes |
| 501 | `unimplemented` | `.badRequest(code)` | E-API-09 | No |
| 503 | `service_unavailable` | `.server(status)` | E-API-08 | Yes |
| 504 | `deadline_exceeded` | `.server(status)` | E-API-08 | Yes |
| any / 200 (failed) | `safety`, `recitation`, `language`, `prohibited_content`, `spii`, `blocklist`, `content_blocked` | `.blocked(reason)` | E-GEN-01 | No |
| 200 | (no text) | `.emptyResponse` | E-GEN-02 | Yes |
| 200 | (undecodable) | `.malformedResponse` | E-GEN-03 | Yes |
| other | unknown or missing code | 4xx → `.badRequest(code)`; 5xx → `.server(status)` | E-API-09 / E-API-08 | per class |

- **Pre-flight errors** (no request sent): `.missingAPIKey` → E-KEY-01; `.keychain(status)` → E-KC-01.
- **⟳ REVALIDATE:**
  - whether an invalid key returns 401 `authentication` (Interactions docs) or 400 (historic `generateContent` behaviour). GEMINI-INT-02 asserts the live behaviour.
  - where generation-blocked codes appear in non-streaming responses: an HTTP error body or a 200 with status `failed`. The parser handles both.
- `Retry-After` is read from the HTTP header (integer seconds) when present. Whether Gemini sends it is **unverified**, so the default is 10 s.

---

## 8. Retry, backoff and quota (P2-09)

- Google's guidance recommends automatic exponential backoff for 429, 408 and 5xx. DOOM deliberately does **not** retry automatically, because "one request per activation" is a product requirement.
- Backoff applies only to the **manual** [Retry] button, as a cooldown:

  | Failure | Cooldown before [Retry] is enabled |
  |---|---|
  | `.rateLimited` | `Retry-After` header value, clamped to 1–60 s; default 10 s |
  | `.server`, `.timedOut`, `.transport`, `.offline`, `.emptyResponse`, `.malformedResponse` | 0 s for the first retry; then 2, 4, 8, 16, 30 s (cap) for consecutive failures on the same captured text |
  | Others | Not retryable |

- Random jitter of ±20 % is applied to computed (non-header) cooldowns. It matters little for a single user, but follows Google's guidance cheaply.
- The cooldown counter lives in memory, and resets with a new activation.
- **Quota:** DOOM does not track or display quota (that would need extra API calls). The user sees E-API-03 or E-API-04 when limits are hit. Free-tier limits are low; this is mentioned in the privacy and setup notes.

---

## 9. API key storage (Keychain) — details in `SECURITY_AND_PRIVACY.md` §2.1

| Attribute | Value |
|---|---|
| Class | `kSecClassGenericPassword` |
| `kSecAttrService` | the bundle identifier (D-23) |
| `kSecAttrAccount` | `"gemini-api-key"` |
| Keychain | data protection keychain (`kSecUseDataProtectionKeychain = true`) |
| Accessibility | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` |
| Synchronizable | `false` |
| Presence check | `SecItemCopyMatching` with `kSecReturnAttributes` only (never `kSecReturnData`) |
| Read | Once per request, immediately before sending. It is not cached in memory beyond the request. |
| Save | Validated (trimmed; 20–256 characters; printable ASCII; no whitespace) → `SecItemAdd`, or `SecItemUpdate` if it exists. On failure nothing is stored (E-KC-02). |
| Remove | `SecItemDelete` (Settings › [Remove]) |
| Error −34018 (`errSecMissingEntitlement`) | `.keychainUnavailable` → E-KC-01. The cause is a build without team signing (D-19). |

- The key format is not checked against a specific prefix, because Google's formats can change. Validation is limited to the basic shape.

---

## 10. Logging limits (category `gemini`)

- **Allowed (public):**
  - request started (model ID);
  - completed (HTTP status, duration ms, output character count, token counts);
  - failed (`GenerationError` case name, HTTP status, provider `code`);
  - cancelled.
- **Never:**
  - request or response bodies;
  - headers;
  - the key, or any prefix or suffix of it;
  - the provider `message`;
  - selected text;
  - output text;
  - thought content;
  - the interaction `id`.

---

## 11. Test doubles and tests (none executed)

### 11.1 Test doubles
- **`StubURLProtocol`** (test target): registered through `URLSessionConfiguration.protocolClasses` on an injected configuration. It returns canned status, headers and body, and records the outgoing `URLRequest` for assertions. No real network.
- **`FakeAIResponder`** (Features tests): conforms to `AIResponding`, returns scripted results or delays, and counts calls.
- **`InMemoryCredentialStore`** (Features tests): conforms to `CredentialStoring`.
- **Fixtures** are synthetic JSON written in test code, modelled on the documented shapes in §6 and §7. They are not captured real responses.

### 11.2 Automated tests

| ID | Test |
|---|---|
| GEMINI-T-01 | Request builder: method POST, exact URL, the `x-goog-api-key` header equals the injected key, **the key is absent from the URL and body**, `store == false`, `stream == false`, `input` equals the text byte-for-byte (including quotes, newlines and Unicode), `system_instruction` equals the constant, and there is no `temperature`. |
| GEMINI-T-02 | Parser: the documented success example → text. Multiple text parts are joined. Thought steps are ignored. The last `model_output` step wins. |
| GEMINI-T-03 | Parser: `incomplete` with text → truncated. Empty text → `.emptyResponse`. Non-JSON → `.malformedResponse`. Over 2 MB → `.malformedResponse`. |
| GEMINI-T-04 | Error mapping: every row of §7 (table-driven). |
| GEMINI-T-05 | `Retry-After` parsing and clamping; cooldown sequence 0, 2, 4, 8, 16, 30, 30 (with jitter bounds). |
| GEMINI-T-06 | Cancellation: a stub that delays; cancel the task → `.cancelled`; the controller applies no result (flow token). |
| GEMINI-T-07 | One request per activation: drive the controller through activation, failure and activation-while-busy; assert the stub request count. |
| GEMINI-T-08 | Logging review grep: no `Logger` call in the `gemini` files interpolates `key`, `body`, `text` or `message`. |

### 11.3 Integration tests (API key required; opt-in; human sets them up)
- They run only when the environment variable `DOOM_LIVE_GEMINI_TESTS=1` **and** `DOOM_GEMINI_TEST_API_KEY` are set **in the test scheme or shell**. This is the test target only; the app target never reads environment variables for keys (D-23).
- Otherwise they are skipped and visibly reported as "skipped".
- Document using `read -s` to avoid shell history.

| ID | Test |
|---|---|
| GEMINI-INT-01 | A live request with a short input → 200, non-empty text, status `completed`. Record the actual response field names for ⟳ revalidation. |
| GEMINI-INT-02 | A deliberately invalid key → record the status and code; assert the mapping to `.invalidAPIKey`. |
| GEMINI-INT-03 | A non-existent model ID → `.modelNotFound`. |
| GEMINI-INT-04 | Cancel 50 ms after start → `.cancelled`, no crash. |

---

## 12. Things that may change (summary of ⟳ items)

- the endpoint and the Interactions schema (`steps` / `model_output` / `status` values);
- the default model ID and its supported `thinking_level` values;
- the token semantics of `max_output_tokens`;
- 401 vs 400 for invalid keys;
- where blocked codes appear;
- the presence of `Retry-After`;
- the storage durations of `store`;
- tier data-use terms.

---

## Sources (consulted 2026-10-24)

- Interactions API reference (request fields, `store`/`stream`, example response): https://ai.google.dev/api/interactions-api
- Interactions overview (GA status, storage defaults, `store=false` constraints): https://ai.google.dev/gemini-api/docs/interactions-overview
- API errors, Interactions (error codes, generation-blocked codes, error JSON format): https://ai.google.dev/gemini-api/docs/api-errors
- API errors, `generateContent` (legacy mapping): https://ai.google.dev/gemini-api/docs/generate-content/api-errors
- Troubleshooting (retry guidance: 429, 408 and 5xx with exponential backoff and jitter): https://ai.google.dev/gemini-api/docs/troubleshooting
- Models and `gemini-3.8-flash` (token limits, thinking levels): https://ai.google.dev/gemini-api/docs/models
- Text generation (thinking-level latency notes): https://ai.google.dev/gemini-api/docs/text-generation
- Logs policy (opt-in logging, retention options): https://ai.google.dev/gemini-api/docs/logs-policy
- Gemini API Additional Terms (unpaid vs paid data use; EEA/CH/UK): Phase 01 research, `ARCHITECTURE.md` Sources
