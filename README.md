# GitOps Platform

Architecture:

GitHub Actions -> Terraform -> EKS -> Argo CD -> Envoy Gateway -> AWS NLB -> Route 53

Platform URLs:
- https://argocd.dglobaleng.com.ng
- https://grafana.dglobaleng.com.ng
- https://prometheus.dglobaleng.com.ng
- https://alertmanager.dglobaleng.com.ng

Workflows:
1. 01-infrastructure.yml: VPC, EKS, ECR, Loki S3/IAM, Addons, Envoy Gateway.
2. 02-bootstrap-argocd.yml: connects to EKS and bootstraps the Argo CD project/root application.
3. 03-wait-for-nlb.yml: waits until Envoy Gateway is programmed and its LoadBalancer Service has an NLB hostname.
4. 04-dns.yml: discovers the NLB by tags and creates Route 53 aliases.
5. 05-health-check.yml: validates Kubernetes resources and public HTTPS endpoints.

Required GitHub secret:
- AWS_TERRAFORM_ROLE_ARN
- ARGOCD_GIT_REPO_URL

Production values to replace:
- domain_name
- acm_certificate_arn
- github_repository (used by Terraform only if desired later)
- cluster_endpoint_public_access_cidrs
- loki_chunks_bucket
- loki_ruler_bucket
- matching bucket names in gitops/applications/loki.yaml
- example.com hostnames
- YOUR_ACM_CERTIFICATE_ARN

Important: the ACM certificate must cover the public hostnames and be in the same AWS region as the NLB. The certificate's private key is never placed in Kubernetes.

The AWS Load Balancer Controller provisions the NLB. Envoy Gateway is the Kubernetes Gateway API controller. Grafana, Prometheus, Loki and Argo CD remain ClusterIP services.

