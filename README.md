# Infosys Konnect APIOps Demo Project

This repository serves as the baseline APIOps demonstration and training project for **Kong Konnect** and **decK**, demonstrating automated delivery from OpenAPI Specifications (OAS) to declarative gateway configuration across enterprise teams.

---

## 🌟 Key Capabilities Demonstrated

1. **5-Stage CI/CD Pipeline (`.github/workflows/kong-konnect-apiops.yml`):**
   - **Stage 1 (Validate):** Syntax check of OAS and decK conversion offline.
   - **Stage 2 (Lint):** Spectral ruleset governance (`.spectral.yaml`) enforcing API design standards.
   - **Stage 3 (Build):** Domain OAS conversion, route patching, and platform team baseline assembly into a single unified `build/kong-render.yaml`.
   - **Stage 4 (Diff):** Non-destructive comparison against the live Konnect Control Plane (`deck gateway diff`).
   - **Stage 5 (Sync):** Idempotent synchronization to Konnect (`deck gateway sync`).

2. **Multi-Domain Federation:**
   - **Flight Data Domain (`flight-data/`):** Flights and Routes APIs.
   - **Sales Domain (`sales/`):** Bookings and Customer Information APIs.
   - **Experience Tier (`experience/`):** GraphQL and unified consumer façade.
   - **Central Platform Team (`platform/`):** Global policies, rate limiting, consumer tiering, and secrets vault configuration.

3. **Isolated Sync via decK Tags:**
   - Configured with `--select-tag infosys-poc-managed` to prevent interfering with other services on shared Control Planes.

4. **Environment Parameterization:**
   - Switch between **US Region** (`https://us.api.konghq.com`) and **India Region** (`https://in.api.konghq.com`).
   - Parametric Control Plane targeting via GitHub Actions environment variables or `.env`.

---

## 🚀 Quick Start (Local)

1. Clone or open this repository:
   ```bash
   cd Infosys-Demo
   ```

2. Copy `.env.example` to `.env` and verify credentials:
   ```bash
   cp .env.example .env
   ```

3. Run linting:
   ```bash
   npx --yes @stoplight/spectral-cli lint "flight-data/**/openapi.yaml" "sales/**/openapi.yaml" --ruleset .spectral.yaml
   ```

4. Build and diff against Konnect Control Plane `infosys-poc-cp`:
   ```bash
   deck gateway diff build/kong-render.yaml --select-tag infosys-poc-managed
   ```

For detailed step-by-step instructions, see the complete [Kong Konnect APIOps Guide](docs/konnect-apiops-guide.md).

---

## 📁 Repository Structure

```
├── .github/
│   └── workflows/
│       └── kong-konnect-apiops.yml   # 5-Stage GitHub Actions Workflow
├── .env.example                      # Template for secrets and variables
├── .env                              # Configured credentials for local demo
├── .spectral.yaml                    # Spectral OAS linting ruleset
├── docs/
│   └── konnect-apiops-guide.md       # Complementary step-by-step APIOps guide
├── experience/                       # Experience API (GraphQL gateway)
├── flight-data/                      # Flight data domain services & OAS specs
├── platform/                         # Platform team policies, plugins & consumers
└── sales/                            # Sales domain services & OAS specs
```
