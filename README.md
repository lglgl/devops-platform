# DevOps Platform · SRE Platform

本地 SRE Lab，运行于 **Docker Desktop Kubernetes (MacBook M4)**，集成可观测性、日志/链路、CI/CD 与 GitOps。

Local SRE lab on Docker Desktop Kubernetes, bundling observability, logging/tracing, CI/CD and GitOps.

---

## 环境 Environment

| 项 Item | 值 Value |
| --- | --- |
| Kubernetes | Docker Desktop Kubernetes |
| StorageClass | `hostpath` |
| IngressClass | `nginx` (ingress-nginx) |
| NodePort | HTTP **30080** / HTTPS **30443** |
| 统一入口 Entry | `http://localhost:30080/` |
| 协议 | 当前仅 HTTP（HTTPS 待接入 cert-manager） |

---

## 命名空间 Namespaces

| Namespace | 内容 Components |
| --- | --- |
| `ingress` | ingress-nginx Controller（统一网关） |
| `observability` | kube-prometheus-stack、Loki、Alloy、Tempo、platform-dashboard |
| `cicd` | Jenkins、Argo CD |
| `infra` *(规划)* | Redis / PostgreSQL / Kafka / Registry |
| `app-*` *(规划)* | 业务应用 |
| `gitlab` | GitLab CE 完整实例（源码托管 + CI/CD，可选，当前未部署，见 `gitlab/`） |

---

## 架构 Architecture

```text
Browser
  |
  | http://localhost:30080
  v
ingress-nginx (ingress ns, NodePort 30080/30443)
  |
  +-- /grafana      -> Grafana          (observability)
  +-- /prometheus   -> Prometheus       (observability)
  +-- /alertmanager -> Alertmanager     (observability)
  +-- /jenkins      -> Jenkins          (cicd)
  +-- /argocd       -> Argo CD          (cicd)
  |
  +-- cluster-internal (no Ingress):
  |     Loki  :3100  <- Alloy (K8s API watch Pods)
  |     Tempo :3200 / OTLP 4317,4318
  |
  +-- 应用 / 仓库 (skeleton):
        /registry  -> Registry (infra,    部署见 registry/)
        /application -> Application (app-sample, 部署见 application/)
  |
  +-- host 路由 (独立域名, 非 path, 需 /etc/hosts):
        gitlab.gitlab.local -> GitLab CE 完整实例 (gitlab ns, 见 gitlab/; 当前未部署)
```

**数据链路 Data flow：**
```text
Pods(stdout) -> Alloy -> Loki -> Grafana(Logs)
Node/K8s     -> node-exporter / kube-state-metrics -> Prometheus -> Grafana(Metrics)
Prometheus   -> Alertmanager -> 通知(Email/Slack/Webhook)
App(OTLP)    -> Tempo -> Grafana(Traces)
```

---

## 首页 Dashboard

`http://localhost:30080/` 分为 5 类 (见 `cicd/dashboard/platform-dashboard.yaml`)：

1. **监控 Monitoring** — Grafana / Prometheus / Alertmanager
2. **日志 Logs & Trace** — Loki / Alloy / Tempo
3. **CICD / GitOps** — Jenkins / Argo CD
4. **APP 应用** — Application / Registry（部署见 `application/`、`registry/`）
5. **其它 Other** — Ingress 网关

---

## 部署顺序 Install Order

1. `ingress-nginx` — 网关（必须先装）
2. `observability/kube-prometheus-stack` — 监控基座
3. `observability/loki` + `observability/alloy` + `observability/tempo` — 日志/链路
4. `cicd` — Jenkins + Argo CD（+ 首页 ConfigMap）
5. （可选）Registry / Application
6. （可选）`gitlab` — 完整 GitLab 实例（源码托管 + CI/CD，见 `gitlab/`，当前未部署）

详细命令见 [docs/operations.md](docs/operations.md)。

---

## 默认账号 Credentials

| 系统 | 用户名 | 密码 |
| --- | --- | --- |
| Grafana | `admin` | `admin123456` |
| Jenkins | `admin` | `admin123456` |
| Argo CD | `admin` | 见 `cicd/argocd/readme.md` |

> 明文密码仅限本地 Lab。生产环境勿在 `values.yaml` 明文保存。

---

## 文档索引 Docs

- [docs/operations.md](docs/operations.md) — 中间件功能 & 启动 / 更新 / 停止 / 挂起
- [docs/ports-connections.md](docs/ports-connections.md) — 端口与连接关系表
- [docs/notes.md](docs/notes.md) — 其它关系与备注

---

## 目录结构 Layout

```text
devops-platform/
├── ingress-nginx/      # NGINX Ingress Controller + 首页 Ingress
├── observability/      # kube-prometheus-stack / loki / alloy / tempo
├── cicd/               # Jenkins + Argo CD + 首页 ConfigMap + Ingress
├── gitlab/             # 完整 GitLab CE 实例部署文件 + 维护文档（未部署）
├── loki-alloy/         # Loki+Alloy 部署实践说明
└── docs/               # 本文档集（含 docs/components/*.md 各组件运维指导）
```
