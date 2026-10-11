#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# SRE CICD 安装脚本
#
# 安装内容：
#   1. Jenkins Controller
#   2. Jenkins Kubernetes Dynamic Agent
#   3. Argo CD
#   4. CICD NGINX Ingress
#   5. SRE Platform 首页
#
# 当前环境：
#   Docker Desktop Kubernetes
#   namespace: cicd
#   StorageClass: hostpath
#   NGINX HTTP: 30080
#   NGINX HTTPS: 30443
#
# 访问地址：
#   Platform:
#       http://localhost:30080/
#
#   Jenkins:
#       http://localhost:30080/jenkins/
#
#   Argo CD:
#       http://localhost:30080/argocd/
#
# Jenkins 默认账号：
#   admin
#
# Jenkins 默认密码：
#   admin123456
# ============================================================


# ============================================================
# 获取脚本所在目录
#
# 不管从哪个目录执行：
#
#   ./install.sh
#
# 都能够正确找到：
#
#   jenkins/values.yaml
#   argocd/values.yaml
#   ingress/cicd-ingress.yaml
#   dashboard/platform-dashboard.yaml
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


# ============================================================
# 输出函数
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'


info() {
  echo -e "${GREEN}==>${NC} $1"
}


warn() {
  echo -e "${YELLOW}WARNING:${NC} $1"
}


error() {
  echo -e "${RED}ERROR:${NC} $1"
}


# ============================================================
# 检查基础命令
#
# Kubernetes 和 Helm 是本安装包的必要依赖。
# ============================================================

info "检查基础命令"

if ! command -v kubectl >/dev/null 2>&1; then
  error "未找到 kubectl"
  exit 1
fi

if ! command -v helm >/dev/null 2>&1; then
  error "未找到 helm"
  exit 1
fi


# ============================================================
# 检查 Kubernetes
#
# cluster-info 能够正常返回，说明当前 kubectl context
# 可以访问 Kubernetes API Server。
# ============================================================

info "检查 Kubernetes"

kubectl cluster-info >/dev/null

echo
echo "当前 Kubernetes Context:"
kubectl config current-context
echo


# ============================================================
# 检查 Helm
# ============================================================

info "检查 Helm"

helm version

echo


# ============================================================
# 检查安装文件
#
# 在真正安装之前检查所有必要文件。
# 避免安装到一半才发现 Values 或 YAML 文件不存在。
# ============================================================

info "检查安装文件"

REQUIRED_FILES=(
  "${SCRIPT_DIR}/jenkins/values.yaml"
  "${SCRIPT_DIR}/argocd/values.yaml"
  "${SCRIPT_DIR}/ingress/cicd-ingress.yaml"
  "${SCRIPT_DIR}/dashboard/platform-dashboard.yaml"
)

for file in "${REQUIRED_FILES[@]}"; do

  if [[ ! -f "${file}" ]]; then
    error "文件不存在:"
    echo "  ${file}"
    exit 1
  fi

done

echo "安装文件检查通过"
echo


# ============================================================
# 创建 cicd Namespace
#
# --dry-run=client + apply：
#   Namespace 已存在时不会报错。
# ============================================================

info "创建 cicd namespace"

kubectl create namespace cicd \
  --dry-run=client \
  -o yaml | kubectl apply -f -

echo


# ============================================================
# 添加 Jenkins 官方 Helm Repository
#
# 如果已经存在，则不重复添加。
# ============================================================

info "检查 Jenkins Helm Repository"

if helm repo list 2>/dev/null | awk '{print $1}' | grep -qx "jenkins"; then

  echo "Jenkins Helm Repository 已存在"

else

  echo "添加 Jenkins Helm Repository"

  helm repo add jenkins \
    https://charts.jenkins.io

fi

echo


# ============================================================
# 添加 Argo CD 官方 Helm Repository
# ============================================================

info "检查 Argo CD Helm Repository"

if helm repo list 2>/dev/null | awk '{print $1}' | grep -qx "argo"; then

  echo "Argo CD Helm Repository 已存在"

else

  echo "添加 Argo CD Helm Repository"

  helm repo add argo \
    https://argoproj.github.io/argo-helm

fi

echo


# ============================================================
# 更新 Helm Repository
# ============================================================

info "更新 Helm Repository"

helm repo update

echo


# ============================================================
# 检查 Jenkins Chart
#
# 如果 Chart 无法找到，立即退出。
# ============================================================

info "检查 Jenkins Helm Chart"

helm search repo jenkins/jenkins

echo


# ============================================================
# 检查 Argo CD Chart
# ============================================================

info "检查 Argo CD Helm Chart"

helm search repo argo/argo-cd

echo


# ============================================================
# 检查 StorageClass
#
# 当前 Docker Desktop Kubernetes：
#
#   hostpath
#
# Jenkins PVC 使用这个 StorageClass。
# ============================================================

info "检查 hostpath StorageClass"

if ! kubectl get storageclass hostpath >/dev/null 2>&1; then

  error "StorageClass hostpath 不存在"

  echo
  echo "当前 StorageClass:"
  kubectl get storageclass

  exit 1

fi

echo "StorageClass hostpath 检查通过"
echo


# ============================================================
# Jenkins Helm Template 验证
#
# 在真正安装之前渲染 Jenkins。
#
# 可以提前发现：
#
#   - Values 类型错误
#   - JCasC 配置错误
#   - Plugin 冲突
#   - Helm Template 错误
# ============================================================

info "验证 Jenkins Helm Template"

helm template jenkins jenkins/jenkins \
  --namespace cicd \
  -f "${SCRIPT_DIR}/jenkins/values.yaml" \
  >/dev/null

echo "Jenkins Template 检查通过"
echo


# ============================================================
# Argo CD Helm Template 验证
#
# 在真正安装之前验证 Argo CD Values。
# ============================================================

info "验证 Argo CD Helm Template"

helm template argocd argo/argo-cd \
  --namespace cicd \
  -f "${SCRIPT_DIR}/argocd/values.yaml" \
  >/dev/null

echo "Argo CD Template 检查通过"
echo


# ============================================================
# 安装或升级 Jenkins
#
# upgrade --install：
#   不存在则安装
#   已存在则升级
#
# --wait：
#   等待资源达到 Ready
#
# --timeout：
#   Docker Desktop 本地环境给 Jenkins 足够启动时间
#
# --atomic：
#   安装或升级失败时自动回滚
#
# Jenkins 第一次启动需要下载插件，因此设置 10 分钟。
# ============================================================

info "安装或升级 Jenkins"

helm upgrade --install jenkins jenkins/jenkins \
  --namespace cicd \
  --create-namespace \
  -f "${SCRIPT_DIR}/jenkins/values.yaml" \
  --wait \
  --timeout 10m \
  --atomic

echo


# ============================================================
# Jenkins 状态检查
# ============================================================

info "检查 Jenkins Pod"

kubectl get pods \
  -n cicd \
  -l app.kubernetes.io/instance=jenkins \
  -o wide

echo


# ============================================================
# 安装或升级 Argo CD
#
# 同样使用：
#
#   --wait
#   --timeout
#   --atomic
#
# 防止 Helm 命令结束时 Argo CD 实际还没有 Ready。
# ============================================================

info "安装或升级 Argo CD"

helm upgrade --install argocd argo/argo-cd \
  --namespace cicd \
  --create-namespace \
  -f "${SCRIPT_DIR}/argocd/values.yaml" \
  --wait \
  --timeout 10m \
  --atomic

echo


# ============================================================
# Argo CD 状态检查
# ============================================================

info "检查 Argo CD Pod"

kubectl get pods \
  -n cicd \
  -l app.kubernetes.io/instance=argocd \
  -o wide

echo


# ============================================================
# 创建 CICD NGINX Ingress
#
# Jenkins：
#
#   /jenkins/
#
# Argo CD：
#
#   /argocd/
# ============================================================

info "创建 CICD NGINX Ingress"

kubectl apply \
  -f "${SCRIPT_DIR}/ingress/cicd-ingress.yaml"

echo


# ============================================================
# 更新 SRE Platform 首页
#
# 首页统一展示：
#
# Observability
#   Grafana
#   Prometheus
#   Alertmanager
#
# CI/CD
#   Jenkins
#   Argo CD
# ============================================================

info "更新 SRE Platform 首页"

kubectl apply \
  -f "${SCRIPT_DIR}/dashboard/platform-dashboard.yaml"

echo


# ============================================================
# 最终状态检查
# ============================================================

info "检查 CICD Pods"

kubectl get pods -n cicd

echo


info "检查 CICD Services"

kubectl get svc -n cicd

echo


info "检查 CICD Ingress"

kubectl get ingress -n cicd

echo


info "检查 Helm Releases"

helm list -n cicd

echo


# ============================================================
# 最终输出
# ============================================================

echo
echo "============================================================"
echo "CICD 安装完成"
echo "============================================================"

echo
echo "SRE Platform:"
echo "  http://localhost:30080/"

echo
echo "Jenkins:"
echo "  http://localhost:30080/jenkins/"
echo "  Username: admin"
echo "  Password: admin123456"

echo
echo "Argo CD:"
echo "  http://localhost:30080/argocd/"

echo
echo "检查命令:"
echo "  kubectl get pods -n cicd"
echo "  kubectl get svc -n cicd"
echo "  kubectl get ingress -n cicd"
echo "  helm list -n cicd"

echo
echo "============================================================"
echo "下一步：验证 Jenkins Kubernetes Dynamic Agent"
echo "============================================================"