# API Linting Deep Dive & Client Defense Q&A

A field engineering guide for explaining, demonstrating, and defending API Linting in Kong Konnect APIOps pipelines for enterprise clients (Infosys, Banking, and Telco accounts).

---

## 1. Why API Linting Matters in Kong Konnect

In a traditional API delivery model, developers write OpenAPI Specs (OAS), convert them to Kong gateway routes, and deploy them. However:
- Without automated linting, **inconsistent URI naming, missing security schemes, missing HTTP error status models, and unstructured payloads** bypass gateway validation and reach the Dev Portal and runtime gateways.
- Broken OAS specs cause silent conversion issues in `deck file openapi2kong`.
- The Developer Portal ends up displaying incomplete documentation, destroying API discoverability.

### API Linting vs. decK Validation

A common customer question is: *"Why do we need Spectral if `deck file validate` already checks our configuration?"*

| Dimension | `deck file validate` | API Linting (`spectral lint`) |
| :--- | :--- | :--- |
| **Layer** | Infrastructure / Gateway Engine | API Contract / Design & Governance |
| **Target** | Kong declarative configuration (`kong.yaml`) | OpenAPI / AsyncAPI / JSON Schema (`openapi.yaml`) |
| **Checks** | Valid Kong plugin schemas, route syntax, upstream host definitions | REST best practices, naming standards, mandatory security schemes, operation IDs, documentation completeness |
| **Stage in SDLC** | Stage 1 (Syntax) & Stage 3 (Build) | Stage 2 (Quality & Governance) |
| **Ownership** | Platform / Gateway Engineering | API Designers, Domain Teams & Governance Committee |

---

## 2. Spectral Ruleset Breakdown (`.spectral.yaml`)

Spectral operates on JSON/YAML documents using built-in or custom functions:

```yaml
extends: ["spectral:oas"]
rules:
  # 1. Formatting tolerance for examples in sample repos
  oas3-valid-media-example: warn

  # 2. Documentation governance (ensures Dev Portal quality)
  operation-description: warn
  info-contact: warn
  info-description: warn

  # 3. Predictable route generation & SDK generation
  operation-operationId: warn

  # 4. Dev Portal catalog categorization
  operation-tags: warn
  operation-tag-defined: warn
```

### Key Enterprise Rules Explained:

1. **`operation-operationId`:**
   - Why it matters for Kong: `deck file openapi2kong` derives route and service identifiers directly from `operationId` or path syntax. Consistent `operationId` naming produces predictable, idempotent Kong route names.
2. **`operation-tags` & `operation-tag-defined`:**
   - Why it matters for Konnect: In the Konnect Dev Portal and Service Catalog, tags group endpoints into business categories. If tags are missing, endpoints appear uncategorized in the portal UI.
3. **`info-contact` & `info-description`:**
   - Why it matters: Service Catalog governance requires an API Owner / Contact for every published service to ensure accountability during security incidents or deprecations.

---

## 3. Advanced Custom Enterprise Rule Examples

Clients often ask: *"Can we write custom rules specific to our bank / organization?"*  
Yes. Here are production-grade examples you can demonstrate:

### Example A: Mandate Enterprise URI Kebab-Case
```yaml
rules:
  paths-kebab-case:
    description: All API path segments must be lowercase kebab-case.
    message: Path segment '{{property}}' must use kebab-case.
    severity: error
    given: $.paths[*]~
    then:
      function: pattern
      functionOptions:
        match: "^(/[a-z0-9]+(-[a-z0-9]+)*|/{[a-zA-Z0-9_]+})+$"
```

### Example B: Enforce Security Schemes (No Unauthenticated Endpoints)
```yaml
rules:
  operation-security-defined:
    description: Every operation must define an explicit security scheme (JWT, OAuth2, or API Key).
    severity: error
    given: $.paths.*[get,post,put,delete,patch]
    then:
      field: security
      function: defined
```

### Example C: Mandate Standard HTTP Error Responses (400, 401, 500)
```yaml
rules:
  mandatory-4xx-5xx-responses:
    description: Operations must declare standard 400 and 500 error responses.
    severity: warn
    given: $.paths.*[get,post,put,delete,patch].responses
    then:
      field: "400"
      function: defined
```

---

## 4. Tough Client Questions & Expert Field Engineer Responses (Q&A)

### Q1: "Developers already complain about slow CI/CD pipelines. Doesn't adding Spectral slow down our builds?"
> **Answer:**  
> *"Spectral is an offline, Node-based CLI that runs entirely in-memory without network calls. Across our test suite containing multiple services and dozens of endpoints, Spectral completed in under 2 seconds. Furthermore, by running linting as **Stage 2** before decK builds or any cloud API calls to Konnect, we fail early and fast if a spec is invalid—saving runner minutes and preventing failed deployments downstream."*

---

### Q2: "Can we start with warnings first so our pipeline doesn't block ongoing team releases?"
> **Answer:**  
> *"Yes, and that is Kong's recommended adoption path. Spectral supports four severity levels: `error`, `warn`, `info`, and `hint`. In our `.spectral.yaml` configuration, we purposefully set rules to `warn`. The pipeline prints actionable feedback in the PR checks without failing the exit code. Once domain teams achieve compliance, governance rules can be graduated to `error` to act as strict deployment gates."*

---

### Q3: "Our developers use VS Code and IntelliJ. Do they have to wait for the GitHub Action to see linting errors?"
> **Answer:**  
> *"No. Because Spectral uses an open standard `.spectral.yaml` file at the repository root, developers can install the official **Stoplight Spectral VS Code Extension** or run `npx @stoplight/spectral-cli lint <path>` in their local terminal. They receive real-time squiggly lines and suggestions as they type their YAML specs, well before creating a pull request."*

---

### Q4: "We already have an API Governance team with an Excel sheet of guidelines. How do we translate that into Spectral?"
> **Answer:**  
> *"Spectral allows extending base rulesets (`spectral:oas`) with custom JSONPath functions. Any rule in your governance checklist—such as requiring version headers (`X-API-Version`), mandating semantic versioning in `info.version`, disallowing verbs in URI paths, or requiring specific OAuth2 scopes—can be codified into 5 lines of declarative YAML in `.spectral.yaml`."*

---

### Q5: "If decK converts OAS to Kong routes (`openapi2kong`), why doesn't decK just enforce our style guide?"
> **Answer:**  
> *"decK is an infrastructure synchronization tool designed to answer: 'Is this a valid Kong Gateway configuration?' decK does not know or care whether your URI is `/getUsers` (bad REST design) or `/users` (good REST design), nor does it enforce whether your API has a description or contact email. Spectral enforces your organization's API design maturity; decK guarantees execution fidelity on the Kong runtime."*

---

### Q6: "How does API Linting integrate with the Kong Dev Portal?"
> **Answer:**  
> *"The Konnect Dev Portal renders directly from OpenAPI specifications. If an OAS file lacks tag definitions, operation descriptions, or response schema examples, the Dev Portal will appear empty, poorly documented, and uninviting to external or internal developers. Linting acts as a quality gatekeeper for the Dev Portal: clean linted specs guarantee a world-class, professional developer portal experience."*
