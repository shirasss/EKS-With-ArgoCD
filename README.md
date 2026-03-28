# EKS with ArgoCD — GitOps on AWS

A production-style Kubernetes platform on AWS EKS, provisioned entirely with Terraform and managed via GitOps using ArgoCD. Includes a sample Flask application with full observability (Prometheus + CloudWatch) and automated CI/CD.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          AWS Cloud (il-central-1)               │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    VPC  10.0.0.0/16                       │   │
│  │                                                           │   │
│  │   Public Subnets (AZ-a / AZ-b)                           │   │
│  │   ├── Internet Gateway                                    │   │
│  │   └── NAT Gateway ──► Private Subnets                    │   │
│  │                                                           │   │
│  │   Private Subnets (AZ-a / AZ-b)                          │   │
│  │   └── EKS Cluster (v1.34)                                │   │
│  │         ├── ingress-nginx (LoadBalancer)                  │   │
│  │         ├── kube-prometheus-stack (Prometheus + Grafana)  │   │
│  │         ├── Fluent Bit ──► CloudWatch Logs               │   │
│  │         ├── ArgoCD                                        │   │
│  │         └── my-app (Flask counter, HPA)                  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ECR ── stores Docker images (lifecycle: keep last 5)           │
│  CloudWatch ── receives logs from Fluent Bit (7-day retention)  │
└─────────────────────────────────────────────────────────────────┘

GitHub (this repo)
  └── push to main
        ├── GitHub Actions: build → push to ECR → update image tag in values.yaml
        └── ArgoCD: detects change → syncs Helm chart to cluster
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Cloud | AWS (EKS, ECR, VPC, CloudWatch, IAM) |
| Infrastructure as Code | Terraform |
| Container Orchestration | Kubernetes (EKS v1.34) |
| GitOps / CD | ArgoCD |
| App Packaging | Helm |
| Ingress | NGINX Ingress Controller |
| Monitoring | kube-prometheus-stack (Prometheus + Grafana) |
| Logging | Fluent Bit → AWS CloudWatch |
| IAM Auth | EKS Pod Identity |
| Application | Python / Flask |
| Container Registry | Amazon ECR |

---

## Repository Structure

```
├── app-code/
│   ├── app.py              # Flask counter app with Prometheus metrics
│   ├── Dockerfile          # Non-root, slim Python image
│   └── requirements.txt
│
├── helm/                   # Helm chart — source of truth for ArgoCD
│   ├── Chart.yaml
│   ├── values.yaml         # Image tag updated automatically by CI
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── ingress.yaml
│       └── hpa.yaml        # CPU-based autoscaling (1–5 replicas)
│
└── Terraform/
    ├── main.tf             # Root module — orchestrates Infra + eks-config
    ├── Infra/              # AWS infrastructure
    │   ├── vpc.tf          # VPC, subnets, IGW, NAT, route tables
    │   ├── eks.tf          # EKS cluster + IAM
    │   ├── node-group.tf   # Managed node group
    │   ├── ecr.tf          # ECR repo + lifecycle policy
    │   └── fluent_bit_cloudwatch.tf  # CloudWatch, Pod Identity, IAM
    └── eks-config/         # In-cluster tools (installed via Helm)
        ├── main.tf         # ingress-nginx, Prometheus, Fluent Bit, ArgoCD
        ├── argocd-app.yaml # ArgoCD Application CRD
        └── values/         # Helm values for each tool
```

---

The counter is stored on a persistent volume, surviving pod restarts. The image tag in `helm/values.yaml` is an immutable git-SHA tag updated by CI, enabling exact rollbacks.

---

## Infrastructure

### VPC
- CIDR `10.0.0.0/16` across two AZs (`il-central-1a`, `il-central-1b`)
- Public subnets for the load balancer; private subnets for the EKS nodes
- NAT Gateway for outbound traffic from private subnets

### EKS
- Kubernetes **v1.34**, private endpoint + public access
- Managed node group in private subnets
- Standard cluster IAM role + node group IAM role with required policies

### ECR
- Repository `app-ecr` for Docker images
- Lifecycle policy keeps only the **last 5 images**

---

## GitOps Flow

1. A push to `main` triggers a **GitHub Actions** workflow that builds the Docker image, pushes it to ECR with a git-SHA tag, and commits the updated tag back to `helm/values.yaml`.
2. **ArgoCD** (running inside the cluster) watches this repo's `helm/` directory.
3. On detecting the new commit, ArgoCD performs an automated sync:
   - `prune: true` — removes Kubernetes resources deleted from Git
   - `selfHeal: true` — reverts any manual `kubectl` changes

---

## Observability

| Signal | Tool | Destination |
|---|---|---|
| Metrics | kube-prometheus-stack | Grafana dashboards in-cluster |
| App metrics | Prometheus client (Flask `/metrics`) | Scraped by Prometheus |
| Logs | Fluent Bit (DaemonSet) | AWS CloudWatch Logs (7-day retention) |

Fluent Bit authenticates to CloudWatch using **EKS Pod Identity** — no static credentials, no IRSA setup required.

---

## Deployment

### Prerequisites
- Terraform ≥ 1.5
- AWS CLI configured with appropriate permissions
- `kubectl` and `helm`

### Provision

```bash
cd Terraform
terraform init
terraform apply -var="github_token=<your_PAT>"
```

Terraform applies in two stages via module `depends_on`:
1. `Infra/` — VPC, EKS, ECR, CloudWatch
2. `eks-config/` — Helm releases (NGINX, Prometheus, Fluent Bit, ArgoCD) + ArgoCD Application

After `apply`, ArgoCD automatically deploys the application from this repo.

---

## Security Highlights

- Container runs as a **non-root user** (`uid 10001`)
- IAM uses **least-privilege** policies scoped to specific CloudWatch log group ARNs
- Fluent Bit uses **EKS Pod Identity** (no long-lived IAM keys)
- ECR images use **immutable SHA tags** (no `latest` in production)

