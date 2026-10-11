# 运维文档 · Operations

中间件功能说明，以及启动 / 更新 / 停止 / 挂起等运维操作。
Component functions and runbook: start / update / stop / suspend.

---

## 零、按组件运维文档 Component Guides

每个组件独立运维指导（功能 / 安装 / 更新 / 停止 / 挂起 / 健康 / 访问 / 排错）：

- [ingress-nginx](components/ingress-nginx.md) — 统一网关
- [kube-prometheus-stack](components/kube-prometheus-stack.md) — Prometheus / Grafana / Alertmanager
- [Loki](components/loki.md) — 日志存储
- [Alloy](components/alloy.md) — 日志采集
- [Tempo](components/tempo.md) — 链路追踪
- [Jenkins](components/jenkins.md) — CI
- [Argo CD](components/argocd.md) — GitOps
- [Registry](components/registry.md) — 镜像仓库
- [Application](components/application.md) — 业务应用示例

---

## 一、中间件功能 Middleware Functions

| 组件 Component | Namespace | 功能 Function |
| --- | --- | --- |
| **ingress-nginx** | `ingress` | 统一 HTTP/HTTPS 网关，按 path 路由到各后端服务 |
| **kube-prometheus-stack** | `observability` | Prometheus(采集) + Grafana(可视化) + Alertmanager(告警) + node-exporter + kube-state-metrics + Prometheus Operator |
| **Grafana** | `observability` | Metrics / Logs / Traces 统一 Dashboard 与数据源 |
| **Prometheus** | `observability` | 拉取（scrape）Metrics、存储、PromQL、告警规则 |
| **Alertmanager** | `observability` | 接收 Prometheus 告警，分组/路由/通知 |
| **Loki** | `observability` | 日志存储后端（单体模式，filesystem + 10Gi PVC） |
| **Alloy** | `observability` | 日志采集 Agent，watch K8s API → Loki Push API |
| **Tempo** | `observability` | 分布式链路追踪后端，接收 OTLP gRPC/HTTP |
| **Jenkins** | `cicd` | CI：Pipeline、构建、测试，K8s 动态 Agent（临时 Pod） |
| **Argo CD** | `cicd` | GitOps：从 Git 拉取 manifests 并同步到 K8s |
| **Registry** | `infra` | 镜像仓库（registry:2），详见 [registry](components/registry.md) |
| **Application** | `app-sample` | 业务应用示例（nginx），详见 [application](components/application.md) |

---

## 二、启动 Start

> 顺序很重要：先网关，再监控，再日志，最后 CI/CD。

```bash
# 1) 网关
cd ingress-nginx && ./install.sh

# 2) 监控基座
cd ../observability/kube-prometheus-stack && ./install.sh

# 3) 日志 & 链路
cd ../loki   && ./install.sh
cd ../alloy  && ./install.sh
cd ../tempo  && ./install.sh

# 4) CI/CD + 首页 ConfigMap
cd ../../cicd && ./install.sh

# 首页 Ingress（如单独部署）
cd ../ingress-nginx && ./apply-dashboard.sh
```

校验：`kubectl get pods -n observability -n cicd`、`helm list -A`。

---

## 三、更新 Update

Helm 托管组件（ingress-nginx / kube-prometheus-stack / Jenkins / Argo CD / Loki / Alloy）直接重跑 install 即 `upgrade --install`：

```bash
helm upgrade --install <release> <chart> -n <ns> -f values.yaml --wait --timeout 10m
```

纯 YAML 组件（Tempo、Ingress、首页 ConfigMap）用 apply：

```bash
kubectl apply -f <file>.yaml
```

修改 Grafana/Prometheus/Alertmanager 子路径配置后，需把 `ingress-nginx/observability-values-patch.yaml` 合并进 `observability/kube-prometheus-stack/values.yaml` 再 upgrade。

---

## 四、停止 Stop（删除）

```bash
# 按依赖反向卸载
cd cicd && ./uninstall.sh                       # Jenkins + Argo CD（保留 Jenkins PVC）
helm uninstall kube-prometheus-stack -n observability
helm uninstall loki -n observability
helm uninstall alloy-logs -n observability
cd observability/tempo && ./uninstall.sh        # 保留 Tempo PVC
helm uninstall ingress-nginx -n ingress

# 删除 namespace（会清空其中所有资源）
kubectl delete namespace cicd observability ingress
```

> Jenkins / Loki / Tempo 的 PVC 默认保留，避免误删数据。

---

## 五、挂起 Suspend（保留资源，仅停负载）

“挂起”= 缩容到 0 副本，不删除资源，随时可恢复。

```bash
# 监控面
kubectl scale deployment -n observability kube-prometheus-stack-grafana --replicas=0
kubectl scale deployment -n observability kube-prometheus-stack-prometheus-operator --replicas=0
kubectl scale statefulset -n observability kube-prometheus-stack-prometheus --replicas=0
kubectl scale statefulset -n observability kube-prometheus-stack-alertmanager --replicas=0

# CI/CD
kubectl scale deployment -n cicd jenkins --replicas=0
kubectl scale deployment -n cicd argocd-server --replicas=0

# 日志/链路（单体）
kubectl scale deployment -n observability loki --replicas=0
kubectl scale deployment -n observability alloy-logs --replicas=0
kubectl scale deployment -n observability tempo --replicas=0
```

**恢复 Resume：** 把 `--replicas=0` 改为 `--replicas=1`（或原副本数）。

**Argo CD 应用级挂起**（不影响 Argo CD 自身）：
```bash
kubectl patch applications.argoproj.io <app> -n cicd --type merge -p '{"spec":{"suspend":true}}'   # 挂起
kubectl patch applications.argoproj.io <app> -n cicd --type merge -p '{"spec":{"suspend":false}}'  # 恢复
```

> 注意：Jenkins PVC 保留，挂起后数据不丢；Prometheus 当前为临时存储，挂起/重启会丢历史数据。

---

## 六、健康检查 & 访问 Health & Access

```bash
kubectl get pods -n observability
kubectl get pods -n cicd
kubectl get ingress -n observability -n cicd
kubectl get svc -n observability -n cicd
```

统一入口：`http://localhost:30080/`（首页 → 5 类卡片）。
各组件直连/port-forward 方式见 [ports-connections.md](ports-connections.md)。

---

## 七、备注 Notes

- 账号明文密码仅限本地 Lab。
- Prometheus 未配 PVC，数据非持久化；Loki/Tempo/Jenkins 有 PVC。
- 集群重启后，被“挂起（replicas=0）”的负载不会自动恢复，需手动 resume。
- 详见 [notes.md](notes.md)。
