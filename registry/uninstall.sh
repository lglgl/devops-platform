#!/bin/bash
# ============================================================
# Registry 卸载脚本
# 默认保留 infra namespace；如需彻底删除再手动删 namespace。
# ============================================================
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> 卸载 Registry"
kubectl delete -f "${DIR}/ingress.yaml"   --ignore-not-found
kubectl delete -f "${DIR}/service.yaml"   --ignore-not-found
kubectl delete -f "${DIR}/deployment.yaml" --ignore-not-found

echo "Registry 已卸载 (infra namespace 保留)。"
echo "如需彻底删除: kubectl delete namespace infra"
