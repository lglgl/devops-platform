# GitLab 运维指导 · Operations

## 1. 功能 Function
完整自托管 GitLab CE 实例（源码托管 + 内置 CI/CD）。经官方 `gitlab/gitlab` Helm chart 部署，
自带 PostgreSQL / Redis / MinIO 对象存储，Runner 负责执行流水线。与平台内 Jenkins / Argo CD 并列的另一套 CI/CD。

## 2. 部署位置 Location
- Namespace：`gitlab`（集群已存在，当前为空，未部署）
- Chart：`gitlab/gitlab`
- 文件：`gitlab/`（namespace / values / install.sh / uninstall.sh）
- 路由：host 路由 `gitlab.gitlab.local`，复用 `ingress-nginx`（IngressClass: nginx）
- 访问：`http://gitlab.gitlab.local:30080`（需 `/etc/hosts`）
- 自带依赖：PostgreSQL / Redis / MinIO（均 PVC 持久化）

## 3. 安装 Start
```bash
cd gitlab && chmod +x install.sh uninstall.sh
./install.sh            # 内部 helm --dry-run 校验
# 校验通过后真正部署:
helm upgrade --install gitlab gitlab/gitlab -n gitlab -f values.yaml --timeout 1200s
```
> ⚠️ 安装前先 `helm show values gitlab/gitlab` 核对 values 字段（随版本变化）；并上调 Docker Desktop 内存 ≥ 8GB。

## 4. 更新 Update
```bash
# 改 values.yaml 后（如升 chart 版本、调资源），重跑幂等升级:
helm upgrade --install gitlab gitlab/gitlab -n gitlab -f values.yaml --timeout 1200s
# 固定版本升级示例: GITLAB_CHART_VERSION=8.x.y ./install.sh (去掉 dry-run 后)
```

## 5. 停止 Stop
```bash
helm uninstall gitlab -n gitlab        # 删 release，保留 namespace 与 PVC
# 彻底删数据: kubectl delete pvc --all -n gitlab
# 彻底删 ns:  kubectl delete namespace gitlab
```

## 6. 挂起 / 恢复 Suspend / Resume
```bash
# Helm 无原生 suspend；用 scale 各 workload 到 0:
kubectl scale deployment --all -n gitlab --replicas=0
# 恢复（按 values 副本数，逐一或整体拉回）:
kubectl scale deployment gitlab-webservice-default -n gitlab --replicas=1
kubectl scale deployment gitlab-sidekiq-all-in-1 -n gitlab --replicas=1
kubectl scale statefulset gitlab-gitaly-0 -n gitlab --replicas=1
```

## 7. 健康检查 Health
```bash
kubectl get pods -n gitlab
kubectl get ingress -n gitlab
curl -I http://gitlab.gitlab.local:30080        # 期望 302 -> /users/sign_in
# root 初始密码:
kubectl -n gitlab get secret gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 -d ; echo
```

## 8. 访问 Access
- Web：`http://gitlab.gitlab.local:30080`（宿主机 `/etc/hosts` 加 `127.0.0.1 gitlab.gitlab.local`）
- Git over HTTP：`http://gitlab.gitlab.local:30080/<group>/<project>.git`
- 如需直连（绕过 ingress）：`kubectl port-forward -n gitlab svc/gitlab-webservice-default 8080:8181`

## 9. 常见问题 Troubleshooting
- **Pending / OOMKilled**：Docker Desktop 内存不足 → 上调分配；或继续压低 `values.yaml` 资源。
- **404 / 打不开**：检查 `/etc/hosts` 与 `ingress-nginx` 状态、Ingress 是否生成。
- **拉镜像 EOF**：网络抖动，重试安装（幂等）。
- **Runner 不在线**：token 正确、runner Pod Running、能回连 GitLab URL。

## 10. 配置要点 Notes
- 已关 chart 自带 nginx-ingress / certmanager / prometheus / grafana，复用平台组件。
- 仅 HTTP（无 TLS），生产需开启 TLS + cert-manager。
- GitLab Runner 默认关闭，按 README 二选一添加。
- 不依赖平台 `infra/registry`；如需 GitLab CI 推镜像到本地仓库，在 `.gitlab-ci.yml` 写 `localhost:30080/registry/...`。
- 监控：可让 Prometheus 额外 scrape GitLab metrics（开 metrics 端口 + 加 scrapeJob），复用 `kube-prometheus-stack`。
