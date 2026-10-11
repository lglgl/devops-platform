#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# 安装前校验。
#
# 通过 Helm template 检查 Jenkins / Argo CD values 是否能够
# 被当前 Helm Chart 正确渲染，同时检查 Kubernetes YAML。
# ============================================================

helm repo add jenkins https://charts.jenkins.io >/dev/null 2>&1 || true
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update >/dev/null

helm template jenkins jenkins/jenkins \
  --namespace cicd \
  -f jenkins/values.yaml >/tmp/jenkins-rendered.yaml

helm template argocd argo/argo-cd \
  --namespace cicd \
  -f argocd/values.yaml >/tmp/argocd-rendered.yaml

kubectl apply --dry-run=client -f ingress/cicd-ingress.yaml
kubectl apply --dry-run=client -f dashboard/platform-dashboard.yaml

echo "校验完成。"
