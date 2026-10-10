# CloudKitchen

[![CI](https://img.shields.io/badge/CI-GitHub%20Actions-2088FF?logo=githubactions&logoColor=white)](.github/workflows)
[![Go](https://img.shields.io/badge/Go-1.22-00ADD8?logo=go&logoColor=white)](https://go.dev)
[![React](https://img.shields.io/badge/React-18-61DAFB?logo=react&logoColor=black)](https://react.dev)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-EKS_%2F_GKE-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?logo=argo&logoColor=white)](https://argo-cd.readthedocs.io)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io)
[![License](https://img.shields.io/badge/license-Personal_&_Educational_Use-orange.svg)](LICENSE)

> A cloud-native, event-driven **food-delivery platform** built as 8 Go
> microservices plus a React frontend, deployed to **AWS EKS or Google GKE**
> via **GitOps** with a full observability and security baseline.

CloudKitchen is a portfolio-grade reference platform demonstrating microservice
design, async messaging, infrastructure-as-code, GitOps delivery, and
production-style monitoring/logging/security.

## What it is

- **8 backend microservices** (`auth`, `user`, `restaurant`, `menu`, `order`,
  `payment`, `delivery`, `notification`) written in Go, each listening on
  `:8080` and exposing `/metrics`, `/healthz`, `/readyz` with structured JSON logs.
- **React frontend** SPA served by nginx.
- **Sync** comms over REST, **async** comms over NATS JetStream events.
- Backed by **PostgreSQL**, **Redis**, and **NATS (JetStream)**.
- Shipped to **EKS** (`eu-north-1`) through **GitHub Actions → ECR  → ArgoCD**.



| Layer            | Technology |
|------------------|------------|
| Backend services | Go 1.22 (HTTP REST, Prometheus client, structured JSON logging) |
| Frontend         | React 18 + Vite, served by nginx |
| Data store       | PostgreSQL 16 |
| Cache / sessions | Redis 7 |
| Messaging        | NATS 2.10 + JetStream (event bus) |
| Containers       | Docker (per-service Dockerfiles) |
| Orchestration    | Kubernetes — **AWS EKS** (`eu-nort-1`) 
| Gateway API      | Envoy |
| GitOps           | ArgoCD (App-of-Apps pattern) |
| Packaging        | Helm (umbrella chart under `helm/cloudkitchen/`) |
| IaC              | Terraform — `aws-terraform/` for AWS (EKS, ECR, IAM/IRSA), `gcp-terraform/` for GCP (GKE, AR, IAM) |
| CI/CD            | GitHub Actions (matrix build, Trivy gate, registry push, values bump) |
| Metrics          | Prometheus (kube-prometheus-stack) + Grafana |
| Logging          | Loki + Promtail |
| Security scan    | Trivy (CI gate + optional trivy-operator) |

## Repository layout (flat monorepo)

```
cloudkitchen-app/
├── auth/            # Go service — authentication & JWT
├── user/            # Go service — user profiles
├── restaurant/      # Go service — restaurant management
├── menu/            # Go service — menu items
├── order/           # Go service — order lifecycle
├── payment/         # Go service — payments
├── delivery/        # Go service — delivery tracking
├── notification/    # Go service — notifications
├── frontend/        # React SPA
├── helm/            # Helm chart(s)
├── terraform/   # AWS infra (VPC, EKS, ECR, IAM/IRSA) — us-east-1
├── argocd/          # ArgoCD Applications (App-of-Apps)
├── monitoring/      # Prometheus + Grafana values & dashboards
├── logging/         # Loki + Promtail values
├── security/        # acm, network policies, PSS, trivy, secrets
├── docker/          # docker-compose local stack
├── docs/            # architecture & docs index
├── .github/         # GitHub Actions workflows
└── README.md
```

## Quickstart (local, docker-compose)

```sh
# from the repo root
docker compose -f docker/docker-compose.yml up --build
```

Then:

| Component    | URL                     |
|--------------|-------------------------|
| Frontend     | http://localhost:3000   |
| auth         | http://localhost:8081   |
| user         | http://localhost:8082   |
| restaurant   | http://localhost:8083   |
| menu         | http://localhost:8084   |
| order        | http://localhost:8085   |
| payment      | http://localhost:8086   |
| delivery     | http://localhost:8087   |
| notification | http://localhost:8088   |
| NATS monitor | http://localhost:8222   |

Seed demo data (users per role, a restaurant, menu items, an order):

```sh
./scripts/seed.sh
```

Full local instructions: [`docker/README.md`](docker/README.md).

## Deployment overview

```mermaid
flowchart LR
    tf[Terraform] --> k8s[("Kubernetes cluster<br/>EKS (AWS) / GKE (GCP)")]
    push[git push] --> gha[GitHub Actions]
    gha --> trivy[Trivy] --> reg[("Container Registry<br/>ECR / GAR")]
    reg --> bump[bump helm/cloudkitchen/values.yaml] --> commit[commit]
    commit --> argo[ArgoCD auto-sync] --> k8s
```

1. **Provision** infrastructure with **Terraform**. On AWS that's VPC + EKS +
   ECR + IAM/IRSA in `us-east-1` (`aws-terraform/`). On GCP that's VPC + GKE +
   Artifact Registry + IAM in `us-central1` (`gcp-terraform/`).
2. **Bootstrap** the cluster: namespaces, Traefik, cert-manager, ArgoCD,
   kube-prometheus-stack, Loki/Promtail.
3. **CI** (GitHub Actions): matrix build per service → **Trivy** scan →
   push to the container registry (**ECR** on AWS, **Artifact Registry** on
   GCP) → bump image tags in `helm/cloudkitchen/values.yaml` → commit.
   **No `helm upgrade` in CI.**
4. **GitOps**: **ArgoCD** detects the committed change and **auto-syncs** the
   Helm release to the Kubernetes cluster.

See the area guides:
[monitoring](monitoring/README.md) ·
[logging](logging/README.md) ·
[security](security/README.md) ·
[docs index](docs/README.md).

## License

**CloudKitchen — Personal & Educational Use License** — see [LICENSE](LICENSE) for the full text.

Quick summary:

| | |
|---|---|
| ✅ **Free, no permission needed** | Clone, fork, run on your own laptop / cloud account for personal study. Modify for your own non-commercial use. Reference the architecture in your own work, with attribution. |
| ❌ **Permission required** | Videos / screencasts / livestreams / paid online courses / tutorials that feature this project. Books or paid newsletters that copy the code or docs. Any commercial reuse (selling, re-hosting as a paid service). |
| 📩 **Want to make educational content?** | Email **vijaygiduthuri67@gmail.com** with who you are, what you want to make, where you'll publish it, and whether it's paid or free. Educational creators with clear attribution are welcome. |

This project was built as a learning artifact for **cloud / DevOps / platform / SRE engineers** and stays free for that purpose. The restriction is on people repackaging it as their own content — not on you learning from it.

> Note: this is a **source-available** license, NOT an OSI-approved open-source license. The badge above reflects that.
