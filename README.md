# EKS Platform — GitOps on AWS

A production-style Kubernetes platform on AWS EKS, built from scratch with Terraform and operated via GitOps using ArgoCD. Covers the full DevOps lifecycle: infrastructure provisioning, CI/CD, container orchestration, observability, DNS management, and security.

---



## Tech Stack

| Layer | Technology |
|---|---|
| Cloud | AWS — EKS, ECR, VPC, CloudWatch, Route53, EBS, IAM |
| Infrastructure as Code | Terraform (modular) |
| Container Orchestration | Kubernetes (EKS v1.34) |
| GitOps / Continuous Delivery | ArgoCD |
| Continuous Integration | GitHub Actions |
| App Packaging | Helm |
| Ingress | NGINX Ingress Controller |
| DNS Automation | External-DNS → Route53 |
| Monitoring | kube-prometheus-stack (Prometheus + Grafana) |
| Pre-built Dashboards | Node Exporter, K8s Cluster, Deployments, Nginx Ingress |
| Logging | Fluent Bit (DaemonSet) → AWS CloudWatch |
| IAM Authentication | EKS Pod Identity (no static keys, no IRSA) |
| Storage | EBS CSI Driver — auto-provisioned PVCs |
| Application | Python / Flask |
| Container Registry | Amazon ECR |

---

## Repository Structure

```
├── app-code/
│   ├── app.py              # Flask counter app with Prometheus /metrics endpoint
│   ├── Dockerfile          # Non-root, slim Python image
│   └── requirements.txt
│
├── helm/                   # Helm chart — ArgoCD watches this directory
│   ├── Chart.yaml
│   ├── values.yaml         # Image tag auto-updated by CI on every push
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── ingress.yaml    # Routes yourdomain.com/ to the app
│       └── hpa.yaml        # CPU-based autoscaling (1–5 replicas)
│
└── Terraform/
    ├── main.tf             # Root module — wires Infra + eks-config together
    ├── variables.tf        # domain_name, github_token
    ├── providers.tf        # AWS, Helm, Kubernetes, kubectl providers
    ├── Infra/              # AWS infrastructure layer
    │   ├── vpc.tf          # VPC, subnets, IGW, NAT, route tables
    │   ├── eks.tf          # EKS cluster, IAM, EBS CSI driver addon
    │   ├── node-group.tf   # Managed node group (t3.medium, private subnets)
    │   ├── ecr.tf          # ECR repo + lifecycle policy (keep last 5 images)
    │   ├── external_dns.tf # IAM role + Pod Identity for External-DNS
    │   └── fluent_bit_cloudwatch.tf  # CloudWatch log group, Pod Identity, IAM
    └── eks-config/         # In-cluster tooling (all via Helm)
        ├── main.tf         # ingress-nginx, Prometheus, Fluent Bit, External-DNS, ArgoCD
        ├── argocd-app.yaml # ArgoCD Application CRD
        └── values/
            ├── prometheus_values.yaml   # Grafana persistence, 4 pre-built dashboards
            ├── argocd-values.yaml       # Sub-path routing (/argocd)
            ├── external-dns-values.yaml # Route53 zone filter, sync policy
            ├── fluent-bit-values.yaml   # CloudWatch log shipping
            └── ingress_values.yaml      # NGINX controller config
```

---

## CI/CD Pipeline

### Continuous Integration (GitHub Actions)
Every push to `main`:
1. Builds a Docker image
2. Pushes to ECR with an **immutable git-SHA tag** (e.g. `a3f9c12...`)
3. Commits the updated tag to `helm/values.yaml` in this repo

### Continuous Delivery (ArgoCD)
1. ArgoCD detects the new commit in `helm/`
2. Renders the Helm chart and applies changes to the cluster
3. `prune: true` — removes resources deleted from Git
4. `selfHeal: true` — reverts any manual `kubectl` changes automatically

---

## Observability

### Metrics — Prometheus + Grafana
- **kube-prometheus-stack** deployed with persistent storage (EBS, 50 GiB)
- Grafana accessible at `yourdomain.com/grafana`
- Pre-loaded dashboards (auto-downloaded at startup):

| Dashboard | What it shows |
|---|---|
| Kubernetes Cluster | Node/pod/deployment health |
| Node Exporter | CPU, memory, disk, network per node |
| Kubernetes Deployments | Replica status, rollout history |
| Nginx Ingress | RPS, p99 latency, error rate |

### Logging — Fluent Bit → CloudWatch
- DaemonSet on every node ships container logs to CloudWatch
- Kubernetes metadata (pod, namespace, labels) merged into every log record
- `/healthz` probe noise filtered before shipping
- Authenticates via **EKS Pod Identity** — zero static credentials

---

## DNS — External-DNS + Route53
- External-DNS watches all Ingress objects in the cluster
- Automatically creates/updates Route53 A records when Ingresses change
- Single domain, path-based routing:

```
yourdomain.com/         → Flask app
yourdomain.com/grafana  → Grafana
yourdomain.com/argocd   → ArgoCD
```

---

## Infrastructure Deployment

### Prerequisites
- Terraform ≥ 1.5
- AWS CLI configured
- `kubectl`, `helm`
- Route53 hosted zone for your domain

### Provision

```bash
cd Terraform
terraform init
terraform apply -var="github_token=<PAT>" -var="domain_name=<yourdomain.com>"
```

Terraform applies in dependency order:
1. **Infra/** — VPC, EKS, ECR, IAM roles, EBS CSI driver, External-DNS IAM
2. **eks-config/** — NGINX, Prometheus, Fluent Bit, External-DNS, ArgoCD, ArgoCD Application

After `apply`, ArgoCD auto-deploys the Flask app. External-DNS creates the Route53 record within ~30 seconds.


## Security

- Containers run as **non-root user** (`uid 10001`)
- IAM roles use **least-privilege** — scoped to specific resource ARNs
- All AWS service access uses **EKS Pod Identity** — no long-lived IAM keys anywhere in the cluster
- ECR images tagged with **immutable git SHAs** — `latest` never used in the cluster
- Node group in **private subnets** — nodes have no public IP
- `.gitattributes` enforces **LF line endings** on all files — prevents CRLF issues in Terraform/Helm on Windows
