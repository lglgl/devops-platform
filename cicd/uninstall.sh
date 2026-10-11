#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# 卸载 CICD 应用。
#
# 默认不删除 Jenkins PVC，避免误删构建历史和 Jenkins 配置。
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

kubectl delete -f "${SCRIPT_DIR}/ingress/cicd-ingress.yaml" --ignore-not-found
helm uninstall argocd -n cicd 2>/dev/null || true
helm uninstall jenkins -n cicd 2>/dev/null || true

echo "CICD 应用已卸载。"
echo "Jenkins PVC 默认保留。"
echo "如需彻底删除：kubectl delete namespace cicd"
