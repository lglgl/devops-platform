#!/usr/bin/env bash

# ============================================================
# Alloy 安装脚本
#
# 运行环境：
#   MacBook M4
#   Docker Desktop Kubernetes
#   observability namespace
#
# 重要：
#   Alloy 的 ServiceAccount / ClusterRole / ClusterRoleBinding
#   全部由 Helm 管理。
#
#   不再执行 rbac.yaml。
#
# ============================================================

set -euo pipefail


# ============================================================
# 1. 基础变量
# ============================================================

NAMESPACE="observability"
RELEASE="alloy-logs"
CHART="grafana/alloy"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES_FILE="${SCRIPT_DIR}/values.yaml"


# ============================================================
# 2. 检查 Helm
# ============================================================

if ! command -v helm >/dev/null 2>&1; then
    echo "ERROR: helm 未安装"
    exit 1
fi


# ============================================================
# 3. 检查 kubectl
# ============================================================

if ! command -v kubectl >/dev/null 2>&1; then
    echo "ERROR: kubectl 未安装"
    exit 1
fi


# ============================================================
# 4. 检查 Kubernetes
# ============================================================

echo "==> Checking Kubernetes"

kubectl cluster-info >/dev/null

echo "Kubernetes connection OK."


# ============================================================
# 5. 检查 Namespace
# ============================================================

echo "==> Checking namespace"

kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 || \
    kubectl create namespace "${NAMESPACE}"


# ============================================================
# 6. 添加 Grafana Helm Repository
# ============================================================

echo "==> Adding Grafana Helm repository"

helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true

helm repo update


# ============================================================
# 7. 检查 values.yaml
# ============================================================

if [ ! -f "${VALUES_FILE}" ]; then
    echo "ERROR: values.yaml 不存在"
    echo "Path: ${VALUES_FILE}"
    exit 1
fi


# ============================================================
# 8. 安装 / 升级 Alloy
# ============================================================
#
# 注意：
# 不再执行：
#
#   kubectl apply -f rbac.yaml
#
# 所有 RBAC 资源交给 Helm。
#
# ============================================================

echo "==> Installing / upgrading Alloy"

helm upgrade --install "${RELEASE}" "${CHART}" \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --values "${VALUES_FILE}"


# ============================================================
# 9. 等待 Deployment
# ============================================================

echo
echo "==> Waiting for Alloy Deployment"

kubectl rollout status deployment/"${RELEASE}" \
    -n "${NAMESPACE}" \
    --timeout=180s


# ============================================================
# 10. 显示结果
# ============================================================

echo
echo "==================== Alloy Pods ===================="

kubectl get pods \
    -n "${NAMESPACE}" \
    -l app.kubernetes.io/name=alloy \
    -o wide


echo
echo "==================== Alloy ServiceAccount ===================="

kubectl get serviceaccount \
    -n "${NAMESPACE}" \
    | grep alloy || true


echo
echo "==================== Alloy RBAC ===================="

kubectl get clusterrole \
    | grep alloy || true

kubectl get clusterrolebinding \
    | grep alloy || true


echo
echo "====================================================="
echo "Alloy installation completed."
echo "====================================================="