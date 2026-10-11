# 端口与连接关系表 · Ports & Connections

---

## 1. 端口表 Port Table

> 当前所有 Web UI 统一经 ingress-nginx 的 **NodePort 30080** 访问（无需 `/etc/hosts`）。
> `Legacy` 列为旧文档提到的直连 NodePort，当前未启用（以 Ingress 为准）。

| 组件 | Namespace | ClusterIP Svc:Port | NodePort (Ingress) | Ingress Path | Port-forward | 说明 |
| --- | --- | --- | --- | --- | --- | --- |
| ingress-nginx | `ingress` | ingress-nginx-controller | **30080** / **30443** | 全部 path 路由 | — | 统一网关 |
| Grafana | `observability` | kube-prometheus-stack-grafana:80 | 30080 | `/grafana` | `3000:80`→`grafana` | Legacy 30030 |
| Prometheus | `observability` | kube-prometheus-stack-prometheus:9090 | 30080 | `/prometheus` | `9090:9090` | 不直接暴露 |
| Alertmanager | `observability` | kube-prometheus-stack-alertmanager:9093 | 30080 | `/alertmanager` | `9093:9093` | Legacy 30031 |
| Loki | `observability` | loki:3100 | — (集群内) | — | `3100:3100` | 日志存储 |
| Alloy | `observability` | (ClusterIP，watch K8s API) | — | — | — | 日志采集 |
| Tempo | `observability` | tempo:3200 / 4317 / 4318 | — (集群内) | — | `13200:3200` | OTLP gRPC/HTTP |
| Jenkins | `cicd` | jenkins:8080 | 30080 | `/jenkins` | `18080:8080` | ClusterIP |
| Argo CD | `cicd` | argocd-server:80 | 30080 | `/argocd` | `8080:80`→`argocd-server` | insecure+rootpath |
| Registry | `infra` *(规划)* | — | 30080 *(规划)* | `/registry` *(规划)* | — | 待部署 |
| Application | `app-*` *(规划)* | — | 30080 *(规划)* | — *(规划)* | — | 待部署 |

**NGINX 关键端口（ingress-nginx/values.yaml）：**
```yaml
controller.service.nodePorts:
  http:  30080
  https: 30443
```

---

## 2. 连接 / 依赖关系 Connection & Dependency

| From | To | 方式 / 端口 | 说明 |
| --- | --- | --- | --- |
| node-exporter | Prometheus | scrape `:9100` | 节点系统指标 |
| kube-state-metrics | Prometheus | scrape | K8s 对象状态 |
| Kubernetes Pods (stdout/stderr) | Alloy | K8s API watch | 采集容器日志 |
| Alloy | Loki | Loki Push API `:3100` | 写入日志 |
| Loki | Grafana | datasource `:3100` | 日志可视化 |
| Prometheus | Grafana | datasource `:9090` | 指标可视化 |
| Prometheus | Alertmanager | alert push `:9093` | 告警分发 |
| App (OTLP SDK) | Tempo | OTLP `:4317`/`:4318` | 上报链路 |
| Tempo | Grafana | datasource `:3200` | 链路可视化 |
| Jenkins Controller | Jenkins Agent | `:8080` | K8s Plugin 动态 Agent（临时 Pod） |
| Argo CD | Git Repo | HTTPS | 拉取 manifests |
| Argo CD | Kubernetes API | — | 同步/apply 应用 |
| ingress-nginx | 所有后端 Service | HTTP path routing | 统一入口（按 path 转发） |

**可视化聚合：** Grafana 同时挂载 Prometheus / Loki / Tempo 数据源，实现 Metrics + Logs + Traces 统一查看。

---

## 3. 账号 Credentials

| 系统 | 用户名 | 密码 / Token | 来源 |
| --- | --- | --- | --- |
| Grafana | `admin` | `admin123456` | `observability/kube-prometheus-stack/README.md` |
| Jenkins | `admin` | `admin123456` | `cicd/jenkins/values.yaml` |
| Argo CD | `admin` | `Goy4PD72E1bUXDTg` | `cicd/argocd/readme.md` |

> 明文密码仅限本地 Lab，生产环境勿明文保存。
