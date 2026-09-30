# Comprehensive Analysis of Infosys Test Environment decK Dump (`kong-onprem-gw-test-bkp.yaml`)

**Date:** October 1, 2026  
**Author:** Niraj Adhikari (Kong Field Engineering)  
**Target Environment:** `kong-onprem-gw-test(Self-managed)`  
**File Size:** 23.4 MB | **Total Lines:** 742,136 lines | **Format Version:** `3.0`  
**Schema Validation:**  Passed (`deck file validate` exits cleanly with code 0)

---

## 1. Executive Summary: What Infosys Has Today

The exported dump file (`kong-onprem-gw-test-bkp.yaml`) is a **massive snapshot** of Infosys's on-premises test environment. 

### High-Level Inventory Metrics:
| Entity Type | Count in Dump | Notes / Observations |
| :--- | :--- | :--- |
| **Services** | **1,231** | Internal microservices across HR, Travel, Banking, and IT domains. |
| **Routes** | **1,802** | Path-based routes matching internal domains (`itgatewaytst.infosysapps.com`, `isgatewaytst.ad.infosys.com`). |
| **Upstreams** | **418** | Upstream load balancers with active and passive health checking. |
| **Targets** | **751** | Backend host/IP endpoints mapped to the upstreams. |
| **Consumers** | **4** | Minimal consumers configured (`infyclient`, `isonpremkongtest`, `itgatewaytst`, UUID). |
| **Consumer Groups** | **1** | Single group: `oidc-group`. |
| **Plugins** | **3,600+ instances** | Heavily dominated by duplicate route-level attachments. |

---

## 2. Deep Dive: Current Plugin Architecture & The "Anti-Pattern"

The analysis reveals an architectural anti-pattern that is causing their dump to be **23.4 MB** and **742,000 lines**:

### Current Plugin Distribution:
```
Total Route-Level Plugin Attachments:
  - acl:             1,797 instances (attached to almost every single route)
  - openid-connect:  1,794 instances (attached to almost every single route)
  - Custom plugins:  ~15 instances (OTPaaS, subsbankportal, etc.)

Global Plugins (At the root level):
  - acl              (Global-ACL)
  - exit-transformer (Custom Lua status/body passthrough)
  - http-log         (Pushes access logs to on-prem Elasticsearch: 10.68.191.97:9200)
  - mtls-auth        (Mutual TLS client authentication)
  - openid-connect   (Azure AD / Microsoft Online OIDC: 63ce7d59-2f3e-42cd-a8cc-be764cff5eb6)
  - prometheus       (Prometheus metrics scraping)
```

### The Root Cause of Configuration Bloat:
1. **Redundant Duplicate Plugins:**  
   Both **`openid-connect`** and **`acl`** are defined as **Global Plugins** (lines 21–542), **AND** they are copied and re-attached across **1,794+ individual routes**!
2. **Hardcoded Identity Providers & Secrets in Config:**  
   Every single route has a 250-line `openid-connect` block hardcoding:
   - Microsoft Azure Entra ID Issuer: `https://login.microsoftonline.com/63ce7d59-2f3e-42cd-a8cc-be764cff5eb6/.well-known/openid-configuration`
   - Corporate Proxy: `http://blrproxy.ad.infosys.com:443`
   - Unique per-route salt hashes (`cache_tokens_salt`).
3. **Massive Upstreams with Full Healthchecks:**  
   All 418 upstreams duplicate a full 50-line health-check definition block with identical interval, timeout, and status codes.

---

## 3. How to Advise Infosys on Plugin Structuring (Talking Points for Next Call)

In your meeting with Muthukumar and Veda, you can present this exact 3-step modernization strategy:

### Recommendation 1: Move Common Auth & Observability to Global / Service Scope
- **Current State:** 1,794 routes each have their own copy of `openid-connect` and `acl`. If Infosys ever rotates an OIDC setting, rotates a cert, or adjusts a timeout, they must patch **1,800 separate blocks**.
- **Konnect Best Practice:**
  - Keep `openid-connect`, `mtls-auth`, `http-log`, and `prometheus` **Global** or attach them at the **Service level** rather than the Route level.
  - Route-level overrides should **only** exist if a specific route needs custom scopes or a different anonymous fallback.
  - **Impact:** Reduces configuration file size by **75%** (from 23MB down to under 5MB) and drastically speeds up decK diff/sync execution times!

### Recommendation 2: Adopt decK Plugin Inheritance (`_plugin_configs`)
- In decK 3.0 / Konnect, decK supports `_plugin_configs` base references:
  ```yaml
  _plugin_configs:
    corporate-azure-oidc:
      name: openid-connect
      config:
        issuer: https://login.microsoftonline.com/63ce7d59.../.well-known/openid-configuration
        https_proxy: http://blrproxy.ad.infosys.com:443
        auth_methods: ["bearer"]
  ```
  Routes and Services simply declare `_config: corporate-azure-oidc` instead of repeating 250 lines of YAML.

### Recommendation 3: Central Platform Defaults vs. Domain Routing
- In your APIOps pipeline (`kong-konnect-apiops.yml`):
  - **Central Platform Team** controls the base policies (`platform/kong/plugins/`): OIDC, ELK `http-log`, `mtls-auth`, and rate limits.
  - **Application Teams** only define their OpenAPI specs (`flight-data/`, `sales/`, `hr/`, `travel/`) and their backend endpoints.
  - decK automatically merges them during **Stage 3 (Build)**, preventing developers from having to configure OIDC or Logging manually.

---

## 4. Observability & Logging Discovery (Relevant to Topic 5)

Notice lines 59–88 in the dump:
Infosys is currently using **`http-log`** to push live access logs directly into an on-premises Elasticsearch cluster:
```text
http_endpoint: http://kongusertst:KongUserTst_32!@10.68.191.97:9200/akskong-infyme-access-on-prem-els/_doc/
```
- **Custom Lua Field:** `upstream_time: return ngx.var.upstream_response_time`
- This directly connects to their **Topic 5 ("Observability with ELK + OpenTelemetry")**!
- In Konnect, this can either continue using `http-log` with buffered queuing, or migrate to native OpenTelemetry (`opentelemetry` plugin) pushing to an OTEL Collector, which then fans out to ELK.

---

## 5. Summary Action Items for Niraj

1. **Email the 4 Pipeline Files to Muthukumar & Veda:**
   - `kong-konnect-apiops.yml`
   - `.spectral.yaml`
   - `.env.example`
   - `docs/konnect-apiops-guide.md`
2. **Review Meeting Deck Structure:**
   - Present the 3-step plugin restructuring strategy (Global vs. Route deduplication).
   - Point out how the ELK `http-log` plugin in this dump can be cleanly managed by the platform team rather than per-team YAMLs.
