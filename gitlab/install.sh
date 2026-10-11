#!/bin/bash
# ============================================================
# GitLab (gitlab ns) 安装脚本 — 由用户手动执行
# 使用官方 gitlab/gitlab Helm chart（完整自托管 GitLab CE）
# 注意: 本脚本不会自动运行，请用户在准备好 Docker Desktop 资源后手动执行。
# ============================================================
set -e

# 非交互 shell 也要能找到 kubectl/helm (Homebrew)
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 可选：固定 chart 版本（取消注释并填入，避免 latest 漂移）
# GITLAB_CHART_VERSION="8.10.0"
VERSION_FLAG="${GITLAB_CHART_VERSION:+--version $GITLAB_CHART_VERSION}"

echo "==> 添加并更新 gitlab Helm repo"
helm repo add gitlab https://charts.gitlab.io 2>/dev/null || true
helm repo update gitlab

echo "==> 确保 namespace: gitlab"
kubectl apply -f "${DIR}/namespace.yaml"

echo "==> 渲染校验 (dry-run, 不实际部署，便于提前发现配置问题)"
helm upgrade --install gitlab gitlab/gitlab -n gitlab \
  -f "${DIR}/values.yaml" ${VERSION_FLAG} \
  --dry-run --debug

echo
echo "============================================================"
echo " 渲染无误后，去掉 --dry-run 真正安装（示例）:"
echo "   helm upgrade --install gitlab gitlab/gitlab -n gitlab \\"
echo "     -f ${DIR}/values.yaml ${VERSION_FLAG} --timeout 1200s"
echo
echo " 提示:"
echo "  - 首次安装: 拉镜像 + 初始化约 10~25 分钟，请耐心等待。"
echo "  - 网络抖动 (EOF/timeout) 请重试；helm upgrade --install 幂等。"
echo "  - 安装后按 README 配置 /etc/hosts 并访问 http://gitlab.gitlab.local:30080"
echo "============================================================"
