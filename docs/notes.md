# 其它关系与备注 · Notes & Remarks

零散但重要的关系说明与设计取舍。

---

## 1. 子路径（subpath）配置必须一致

Grafana / Prometheus / Alertmanager 经过 ingress 的 `/grafana` `/prometheus` `/alertmanager` 子路径访问，
其应用自身也必须知道子路径，否则资源（JS/CSS/API）404。

- `ingress-nginx/observability-values-patch.yaml` 提供补丁
- 合并进 `observability/kube-prometheus-stack/values.yaml`：

```yaml
grafana:
  grafana.ini:
    server:
      root_url: "%(protocol)s://%(domain)s/grafana/"
      serve_from_sub_path: true
prometheus:
  prometheusSpec:
    externalUrl: "http://localhost:30080/prometheus/"
    routePrefix: "/prometheus"
alertmanager:
  alertmanagerSpec:
    externalUrl: "http://localhost:30080/alertmanager/"
    routePrefix: "/alertmanager"
```

---

## 2. Ingress 与 backend 同 Namespace 设计

- NGINX Controller 在 `ingress` namespace
- 但 Ingress 对象分别位于 `observability` 与 `cicd`

原因：Kubernetes 要求 **Ingress 的 backend Service 必须与 Ingress 同 namespace**。
因此：

```text
ingress      └── NGINX Ingress Controller
observability└── Ingress(首页/ Grafana / Prometheus / Alertmanager)
cicd         └── Ingress(/jenkins / /argocd)
```

两个 Ingress 都不设 host，都匹配 `localhost:30080`；按 path 长度优先：
`/jenkins`、`/argocd` 优先于首页的 `/`。

---

## 3. Jenkins 反向代理（Reverse Proxy）

Jenkins 经 ingress 子路径 `/jenkins` 访问，必须：

- `cicd/ingress/cicd-ingress.yaml` 设置
  `nginx.ingress.kubernetes.io/proxy-set-headers: cicd/jenkins-proxy-headers`
- `cicd/jenkins/values.yaml` 的 `controller.jenkinsUrl` 指向入口地址

否则 Jenkins “ReverseProxySetupMonitor” 告警（误以为外部地址是 `localhost` 而非 `localhost:30080`）。

Jenkins Agent 不常驻：Pipeline 运行时由 K8s Plugin 动态创建临时 Agent Pod，
完成后自动删除（`podRetention: Never`，`containerCap: 3`）。

---

## 4. Legacy NodePort 30030 / 30031

旧 README 提到 Grafana(`30030`)、Alertmanager(`30031`) 直连 NodePort。
当前 `kube-prometheus-stack/values.yaml` 中 `service.type: ClusterIP`，
**统一走 ingress 30080**。以 Ingress 为准；30030/30031 为历史文档残留。

---

## 5. 数据持久化 Persistence

| 组件 | 持久化 | 说明 |
| --- | --- | --- |
| Jenkins | PVC 10Gi (hostpath) | `uninstall.sh` 默认保留 PVC |
| Loki | PVC 10Gi (hostpath) | 单体 filesystem 模式 |
| Tempo | PVC 10Gi (hostpath) | `uninstall.sh` 保留，需手动 `kubectl delete pvc tempo-data` |
| Prometheus | **无 PVC（临时）** | 重启/挂起丢历史数据，后续再加 PVC |

---

## 6. 高可用与未来规划

- 当前均为单副本 Lab 配置，**非 HA**。
- Loki 后续可升级为 Distributed + S3/MinIO；Alloy 升级为 DaemonSet。
- 未来接入 **HTTPS + cert-manager + Let's Encrypt** 作为正式 TLS 入口层。
- 待部署：**Registry (Harbor, infra)**、**Application (app-*)**，并加 ingress path。
- 账号明文密码仅限本地 Lab，生产勿明文。

---

## 7. 首页卡片与真实组件映射

`cicd/dashboard/platform-dashboard.yaml`（ConfigMap）首页分 5 类：

| 分类 | 卡片 | 链接 | 状态 |
| --- | --- | --- | --- |
| 监控 | Grafana / Prometheus / Alertmanager | `/grafana` `/prometheus` `/alertmanager` | 在线 |
| 日志 | Loki / Alloy / Tempo | `/grafana/explore` | 在线（集群内） |
| CICD | Jenkins / Argo CD | `/jenkins` `/argocd` | 在线 |
| APP | Application / Registry | `/application` `/registry` | 已联动（部署见 application/ registry/） |
| 其它 | Ingress 网关 | `#` | Gateway |

> 说明：你列出的 7 项（Grafana/Prometheus/Alertmanager/Jenkins/ArgoCD/Registry/Application）
> 已归入对应分类；**日志**分类补充了仓库内真实存在的 Loki/Alloy/Tempo 后端。
> Registry / Application 已有部署骨架（`registry/`、`application/`），部署后首页卡片即可点击。
> 如需调整分类或链接，改此 ConfigMap 后 `kubectl apply` 即可。
