# GitLab · 完整自托管实例 (CI/CD)

基于官方 `gitlab/gitlab` Helm chart 的完整 GitLab CE 实例，承担源码托管 + 内置 CI/CD（Runner）。
与平台已有的 Jenkins / Argo CD 并列，作为另一套可选的 CI/CD 体系。

> ⚠️ **当前状态：未部署 (NOT deployed)。** 本目录仅提供部署文件与维护文档，由用户手动执行 `install.sh` 部署。
> 集群中 `gitlab` namespace 已存在（空），`gitlab` Helm repo 已添加。

---

## 部署位置 (规划)

| 项 | 值 |
| --- | --- |
| Namespace | `gitlab` |
| Chart | `gitlab/gitlab`（完整 GitLab CE） |
| 路由 | host 路由：`gitlab.gitlab.local`（非 path，GitLab 不支持 path 入口） |
| Ingress | 复用 `ingress-nginx`（IngressClass: nginx），HTTP 仅 |
| 访问 | `http://gitlab.gitlab.local:30080` |
| 自带依赖 | PostgreSQL / Redis / MinIO（对象存储），均 PVC 持久化 |
| 资源 | 重组件，建议 Docker Desktop ≥ 8GB（建议 12GB+）内存 |

---

## 文件

```text
gitlab/
├── namespace.yaml    # gitlab namespace
├── values.yaml       # 面向 docker-desktop 的精简调优 values（核心配置）
├── install.sh        # 手动安装（helm upgrade --install，含 dry-run 校验）
├── uninstall.sh      # 手动卸载
└── README.md         # 本文档
```

> values.yaml 顶部已注明：安装前请 `helm show values gitlab/gitlab` 核对当前版本字段，
> 因为 chart 的 value 结构会随版本变化。

---

## 安装 / 卸载（手动）

```bash
cd gitlab && chmod +x install.sh uninstall.sh

# 1) 先渲染校验（不实际部署），确认配置无误
./install.sh            # 内部跑 helm --dry-run --debug

# 2) 校验通过、且 Docker Desktop 内存已上调后，去掉 --dry-run 真正安装
helm upgrade --install gitlab gitlab/gitlab -n gitlab \
  -f values.yaml --timeout 1200s

# 卸载（保留数据）
./uninstall.sh
```

首次安装：拉镜像 + 初始化约 **10~25 分钟**。网络抖动（EOF/timeout）请重试，`helm upgrade --install` 幂等。

---

## 访问 Access（host 路由）

GitLab chart 使用 **host 路由**（非 `/gitlab` path，GitLab 对 path 入口支持很差）。
需在宿主机 `/etc/hosts` 添加（如启用 MinIO/Registry 子域名也一并加）：

```text
127.0.0.1 gitlab.gitlab.local registry.gitlab.local minio.gitlab.local
```

然后浏览器访问：

```text
http://gitlab.gitlab.local:30080
```

首次登录 root 密码从 Secret 取：

```bash
kubectl -n gitlab get secret gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 -d ; echo
```

---

## 配置要点 Notes

- **关闭了 chart 自带的** nginx-ingress / certmanager / prometheus / grafana，复用本平台组件。
- **仅 HTTP（无 TLS）**：本地 Lab 可接受；生产务必开启 TLS + cert-manager。
- **资源已压低**：仍较重，务必先上调 Docker Desktop 内存，否则 Pod 会 OOM / Pending。
- **GitLab Runner 默认关闭**：避免自动注册半成品。GitLab 起来后再加 Runner（见下）。

---

## 添加 CI/CD Runner（二选一）

**(a) 开启 bundled runner：** 编辑 `values.yaml`，将 `gitlab-runner.enabled: true`，
并在 GitLab UI（Admin → CI/CD → Runners）创建 token 后填入 `runners.registrationToken`，重跑 `helm upgrade --install`。

**(b) 单独部署 gitlab-runner chart（推荐，更可控）：**
```bash
helm repo add gitlab https://charts.gitlab.io
helm upgrade --install gitlab-runner gitlab/gitlab-runner -n gitlab \
  --set gitlabUrl=http://gitlab.gitlab.local:30080 \
  --set runnerRegistrationToken=<UI 获取的 token>
```

---

## 健康检查 Health

```bash
kubectl get pods -n gitlab                      # 所有 Pod Running
kubectl get ingress -n gitlab                   # 各 host 的 Ingress 已建
curl -I http://gitlab.gitlab.local:30080        # 期望 302 -> /users/sign_in
```

---

## 常见问题 Troubleshooting

- **Pod Pending / OOMKilled**：Docker Desktop 内存不足 → 上调分配；或进一步压低 `values.yaml` 的资源。
- **页面打不开 / 404**：检查 `/etc/hosts` 是否加了 `gitlab.gitlab.local`；确认 `ingress-nginx` 正常、Ingress 已生成。
- **首次拉镜像 EOF**：本机到 `registry.gitlab.com` / Docker Hub 网络抖动，重试安装脚本即可。
- **Runner 不在线**：确认 token 正确、runner Pod Running，且能回连 GitLab URL（host 可达）。

---

## 与现有平台的关系

- 与 **Jenkins / Argo CD** 并列，是另一套可选的 CI/CD；三者互不依赖，可共存。
- GitLab 自带 PostgreSQL/Redis/MinIO，**不依赖** 平台 `infra` 的 Registry；
  若想让 GitLab CI 推送镜像到本地 `infra/registry`，在 `.gitlab-ci.yml` 里把仓库地址写为
  `localhost:30080/registry/...`（需 Docker 配置 insecure registry）。
- 可观测性：GitLab 指标可经 Prometheus 额外 scrape（需给 GitLab 暴露 metrics 端口并加 scrapeJob），
  本 `values.yaml` 已关 chart 自带 Prometheus，复用平台 `kube-prometheus-stack`。

---

## 后续可选（手动）

- 在首页 `cicd/dashboard/platform-dashboard.yaml` 的 **CICD** 分类加 GitLab 卡片：
  加一个链接到 `http://gitlab.gitlab.local:30080` 的卡片，然后
  `kubectl apply -f cicd/dashboard/platform-dashboard.yaml && kubectl rollout restart deployment/platform-dashboard -n observability`。
- 接入 TLS：开启 `global.ingress.tls.enabled: true` + cert-manager（见 docs/notes.md 规划）。
