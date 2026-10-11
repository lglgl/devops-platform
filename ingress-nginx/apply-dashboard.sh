#!/bin/bash

# ============================================================
# 部署平台首页和 Observability Ingress
#
# 执行前提：
#   1. ingress-nginx 已经安装
#   2. kube-prometheus-stack 已经安装
#   3. observability Namespace 已经存在
# ============================================================

set -e

echo "=============================================="
echo " 部署 Kubernetes SRE Platform Dashboard"
echo "=============================================="

# ============================================================
# 1. 检查 Namespace
# ============================================================

echo
echo "[1/4] 检查 Namespace..."

kubectl get namespace observability

# ============================================================
# 2. 部署 Dashboard
# ============================================================

echo
echo "[2/4] 部署 Dashboard..."

kubectl apply -f dashboard.yaml

# ============================================================
# 3. 等待 Dashboard Pod
# ============================================================

echo
echo "[3/4] 等待 Dashboard Ready..."

kubectl rollout status   deployment/platform-dashboard   -n observability   --timeout=120s

# ============================================================
# 4. 查看结果
# ============================================================

echo
echo "[4/4] 查看资源..."

kubectl get pods -n observability
kubectl get svc -n observability
kubectl get ingress -n observability

echo
echo "=============================================="
echo " Dashboard 部署完成"
echo "=============================================="
echo
echo "打开："
echo
echo "http://localhost:30080"
echo
echo "然后点击："
echo
echo "  Grafana"
echo "  Prometheus"
echo "  Alertmanager"
echo
