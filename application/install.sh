#!/bin/bash
# ============================================================
# Application (app-sample namespace) 安装脚本
# 示例业务应用：nginx:alpine，经 ingress /application 暴露
# ============================================================
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> 部署 Application (namespace: app-sample)"
kubectl apply -f "${DIR}/namespace.yaml"
kubectl apply -f "${DIR}/deployment.yaml"
kubectl apply -f "${DIR}/service.yaml"
kubectl apply -f "${DIR}/ingress.yaml"

echo "==> 等待 Application Ready"
kubectl rollout status deployment/app-sample -n app-sample --timeout=120s

echo
echo "=============================================="
echo " Application 部署完成"
echo " 访问: http://localhost:30080/application/"
echo " 替换镜像: 编辑 deployment.yaml 的 image 字段"
echo "=============================================="
