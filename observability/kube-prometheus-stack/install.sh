#!/bin/bash

# ============================================================
# kube-prometheus-stack 安装脚本
#
# 功能：
#   1. 检查 Kubernetes
#   2. 创建 observability Namespace
#   3. 添加 Prometheus Community Helm Repository
#   4. 更新 Helm Repository
#   5. 安装 kube-prometheus-stack
#   6. 等待核心 Pod
#   7. 输出访问信息
# ============================================================

set -e

NAMESPACE="observability"
RELEASE_NAME="kube-prometheus-stack"
CHART_REPO="https://prometheus-community.github.io/helm-charts"

echo "=============================================="
echo " kube-prometheus-stack"
echo " Prometheus + Grafana + Alertmanager"
echo "=============================================="

# ============================================================
# 1. 检查 Kubernetes
# ============================================================

echo
echo "[1/6] 检查 Kubernetes..."

kubectl cluster-info

# ============================================================
# 2. 创建 Namespace
# ============================================================

echo
echo "[2/6] 创建 observability Namespace..."

kubectl apply -f namespace.yaml

# ============================================================
# 3. 添加 Helm Repository
# ============================================================

echo
echo "[3/6] 添加 Prometheus Community Helm Repository..."

helm repo add prometheus-community "$CHART_REPO" 2>/dev/null || true
helm repo update

# ============================================================
# 4. 安装 / 升级 kube-prometheus-stack
#
# 使用 upgrade --install：
#   - 第一次执行：安装
#   - 后续执行：升级
# ============================================================

echo
echo "[4/6] 安装 kube-prometheus-stack..."

helm upgrade --install "$RELEASE_NAME"   prometheus-community/kube-prometheus-stack   --namespace "$NAMESPACE"   --values values.yaml   --wait   --timeout 10m

# ============================================================
# 5. 检查核心组件
# ============================================================

echo
echo "[5/6] 检查 Prometheus / Grafana / Alertmanager..."

kubectl get pods -n "$NAMESPACE" -o wide

echo
echo "Services:"
kubectl get svc -n "$NAMESPACE"

# ============================================================
# 6. 输出访问地址
# ============================================================

echo
echo "[6/6] 访问地址"
echo
echo "Grafana:"
echo "  http://localhost:30030"
echo
echo "  Username: admin"
echo "  Password: admin123456"
echo
echo "Alertmanager:"
echo "  http://localhost:30031"
echo
echo "Prometheus:"
echo "  默认不直接暴露到 NodePort"
echo "  如需访问，可执行："
echo "  kubectl port-forward -n observability svc/kube-prometheus-stack-prometheus 9090:9090"
echo
echo "Prometheus:"
echo "  http://localhost:9090"
echo
echo "=============================================="
echo " 安装完成"
echo "=============================================="
