#!/usr/bin/env bash
set -Eeuo pipefail

# 始终从脚本所在目录读取资源文件。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 检查 kubectl 与集群连接。
command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl 不可用" >&2; exit 1; }
kubectl cluster-info >/dev/null

# 创建命名空间，已存在时保持不变。
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -

# 按资源依赖顺序安装 Tempo。
kubectl apply -f tempo-config.yaml
kubectl apply -f tempo-pvc.yaml
kubectl apply -f tempo-deployment.yaml
kubectl apply -f tempo-service.yaml

# 等待工作负载就绪并显示资源状态。
kubectl rollout status deployment/tempo -n observability --timeout=300s
kubectl get pods,svc,pvc -n observability -o wide
echo "Tempo 安装流程完成。"
