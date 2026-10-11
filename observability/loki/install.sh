#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="observability"
RELEASE="loki"

echo "==> Adding Grafana Community Helm repository"
helm repo add grafana-community https://grafana-community.github.io/helm-charts 2>/dev/null || true
helm repo update

echo "==> Checking namespace"
kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 || \
  kubectl create namespace "${NAMESPACE}"

echo "==> Installing / upgrading Loki"
helm upgrade --install "${RELEASE}" grafana-community/loki \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  -f "$(dirname "$0")/values.yaml"

echo
echo "==> Loki resources"
kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/name=loki
kubectl get pvc -n "${NAMESPACE}"
kubectl get svc -n "${NAMESPACE}" | grep loki || true

echo
echo "Loki installation completed."
