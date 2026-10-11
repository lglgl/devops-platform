#!/bin/bash

# ============================================================
# kube-prometheus-stack 卸载脚本
#
# 注意：
#   该脚本会删除 Helm Release。
#   同时删除 observability Namespace。
# ============================================================

set -e

NAMESPACE="observability"
RELEASE_NAME="kube-prometheus-stack"

echo "=============================================="
echo " 卸载 kube-prometheus-stack"
echo "=============================================="

# ============================================================
# 1. 卸载 Helm Release
# ============================================================

echo
echo "[1/2] 卸载 Helm Release..."

helm uninstall "$RELEASE_NAME"   --namespace "$NAMESPACE"   || true

# ============================================================
# 2. 删除 Namespace
# ============================================================

echo
echo "[2/2] 删除 observability Namespace..."

kubectl delete namespace "$NAMESPACE"   --ignore-not-found=true

echo
echo "卸载完成。"
