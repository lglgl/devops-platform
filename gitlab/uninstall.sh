#!/bin/bash
# ============================================================
# GitLab 卸载脚本 (gitlab ns) — 由用户手动执行
# 默认保留 namespace 与 PVC（保留数据）；取消注释可彻底清理。
# ============================================================
set -e

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> 卸载 GitLab Helm release (保留 namespace)"
helm uninstall gitlab -n gitlab || true

echo "==> 查看残留 PVC（默认不删，避免误删数据）"
kubectl get pvc -n gitlab

echo
echo "============================================================"
echo " 如需彻底删除 PVC（数据不可恢复！谨慎）:"
echo "   kubectl delete pvc --all -n gitlab"
echo
echo " 如需删除整个 namespace（含所有资源与 PVC）:"
echo "   kubectl delete namespace gitlab"
echo "============================================================"
