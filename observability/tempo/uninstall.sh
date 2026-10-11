#!/usr/bin/env bash
set -Eeuo pipefail

# 从脚本所在目录执行删除，避免资源文件路径错误。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 删除工作负载、服务和配置，保留 PVC 以保护 Trace 数据。
kubectl delete -f tempo-service.yaml --ignore-not-found
kubectl delete -f tempo-deployment.yaml --ignore-not-found
kubectl delete -f tempo-config.yaml --ignore-not-found

echo "Tempo 已卸载；PVC tempo-data 保留。确认无需数据后可手动删除该 PVC。"
