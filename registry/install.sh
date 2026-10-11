#!/bin/bash
# ============================================================
# Registry (infra namespace) 安装脚本
# 镜像仓库：registry:2，经 ingress /registry 暴露
# ============================================================
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> 部署 Registry (namespace: infra)"
kubectl apply -f "${DIR}/namespace.yaml"
kubectl apply -f "${DIR}/deployment.yaml"
kubectl apply -f "${DIR}/service.yaml"
kubectl apply -f "${DIR}/ingress.yaml"

echo "==> 等待 Registry Ready"
kubectl rollout status deployment/registry -n infra --timeout=120s

echo
echo "=============================================="
echo " Registry 部署完成"
echo " 访问: http://localhost:30080/registry/"
echo " 推镜像示例:"
echo "   docker tag myapp:latest localhost:30080/registry/myapp:latest"
echo "   docker push localhost:30080/registry/myapp:latest"
echo "=============================================="
