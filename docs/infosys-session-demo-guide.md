# Production Restructuring Demo & Presentation Guide

**Session Date:** October 6, 2026 | 10:30 AM – 11:30 AM IST  
**Audience:** Muthukumar Subramanian, Veda Bhat, Sabarathinam, Infosys Architecture Team  
**Presenter:** Niraj Adhikari (Kong Field Engineering)

---

## 1. What We Found in the Test Dump (`kong-onprem-gw-test-bkp.yaml`)

When analyzing Veda’s test backup:
* **Total size:** 23.4 MB (742,136 lines) containing **1,231 Services**, **1,802 Routes**, and **418 Upstreams**.
* **The Root Cause of Bloat:**  
  Over **1,794 copies of `openid-connect`** and **1,797 copies of `acl`** are hardcoded into individual routes!
* **The Business Domains Discovered from URI Prefixes:**
  1. `/infydigital/*` (1,253 routes — e.g. `CCPServices`, `DomesticMasterData`)
  2. `/pfapis/*` (267 routes)
  3. `/infyidm/*` (30 routes)
  4. `/onestop/*` (26 routes)
  5. `/alumni/*`, `/infysso/*`, `/icaapp/*`, etc.

---

## 2. The Restructured Production Blueprint (Option A: Federated APIOps)

Instead of maintaining a 742,000-line monolithic file where any change risks breaking 1,200 services:

```mermaid
flowchart TD
    subgraph Platform_Layer ["1. Central Platform Security & Observability"]
        A["platform/plugins/platform-baseline-policies.yaml"]
        B["Global Azure AD OIDC + Global ACL + ELS Logging + Prometheus"]
        A --> B
    end

    subgraph Domain_Layer ["2. Federated Domain Repositories (OAS-First)"]
        C["domains/infydigital/ccp-services/openapi.yaml"]
        D["domains/infydigital/ccp-services/patches.yaml"]
        C --> E["deck file openapi2kong"]
        D --> E
    end

    subgraph Deployment_Layer ["3. Isolated Tag-Based Sync (--select-tag)"]
        E --> F["deck gateway sync --select-tag domain:infydigital"]
        B --> G["Konnect Control Plane (infosys-poc-cp)"]
        F --> G
    end
```

### Key Innovations:
1. **Deduplication:** Azure AD OIDC (`login.microsoftonline.com/63ce7d59...`), corporate proxy (`blrproxy.ad.infosys.com:443`), and Elasticsearch logging (`10.68.191.97:9200`) are maintained **once** by the platform team.
2. **Domain Isolation via Selective Tagging:**  
   The `infydigital` domain syncs with `--select-tag domain:infydigital`. It touches **only** its 6 entities. It never interferes with `pfapis`, `onestop`, or other teams.
3. **OpenAPI Specification (OAS-First):**  
   Developers define clean contracts (`openapi.yaml`). decK compiles them into gateway routes automatically.

---

## 3. Live Demonstration Walkthrough (Step-by-Step Script)

### Step 1: Show the Problem in the Dump File
Open `docs/kong-onprem-gw-test-bkp.yaml`:
> *"Look at lines 560 to 630. For the very first service (`CCPServices`), we have 250 lines defining Azure AD OIDC and ACL. Scroll to line 960 (`DomesticMasterData`)—the exact same 250 lines are repeated. Across 1,800 routes, that is why this file is 23 Megabytes."*

### Step 2: Show the Clean Domain OpenAPI Spec
Open [`demo-restructured/domains/infydigital/ccp-services/openapi.yaml`](file:///c:/Users/nadhi/source-repos/Infosys-Demo/demo-restructured/domains/infydigital/ccp-services/openapi.yaml):
> *"In our recommended structure, the Digital team only owns their clean OpenAPI 3.0 specification. They define their paths (`/infydigital/CCPServices`), summaries, and status codes."*

### Step 3: Show the Declarative Compilation & Tagging
Run in terminal:
```powershell
deck file openapi2kong -s demo-restructured/domains/infydigital/ccp-services/openapi.yaml | `
  deck file patch demo-restructured/domains/infydigital/ccp-services/patches.yaml | `
  deck file add-tags -o demo-restructured/build/infydigital-ccp-kong.yaml "domain:infydigital" "api:ccp-services"
```
Show output: A clean **67-line** production configuration file with tags:
- `domain:infydigital`
- `api:ccp-services`

### Step 4: Show Isolated Non-Destructive Diff & Sync
Run diff:
```powershell
deck gateway diff demo-restructured/build/infydigital-ccp-kong.yaml `
  --konnect-addr "https://us.api.konghq.com" `
  --konnect-control-plane-name "infosys-poc-cp" `
  --konnect-token "$KONNECT_TOKEN" `
  --select-tag "domain:infydigital"
```
> *"Notice that decK diff only inspects and changes entities tagged with `domain:infydigital`. It is completely blind to and protected from the rest of the 3,000 APIs in Konnect."*

Run sync:
```powershell
deck gateway sync demo-restructured/build/infydigital-ccp-kong.yaml `
  --konnect-addr "https://us.api.konghq.com" `
  --konnect-control-plane-name "infosys-poc-cp" `
  --konnect-token "$KONNECT_TOKEN" `
  --select-tag "domain:infydigital"
```
**Result in Konnect Control Plane:**
- `infosys-digital-ccp-services-api` is live.
- Tags: `domain:infydigital`, `api:ccp-services`.
- Zero blast radius across the rest of the enterprise.
