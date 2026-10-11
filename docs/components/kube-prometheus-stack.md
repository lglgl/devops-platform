# kube-prometheus-stack 运维指导 · Operations

> 一个 Helm Release 同时包含 **Prometheus / Grafana / Alertmanager** 三件套，外加 node-exporter、kube-state-metrics、Prometheus Operator。运维以该 Release 为单位。

## 1. 功能 Function
- **Prometheus**：拉取（scrape）Metrics、存储、PromQL 查询、告警规则评估。
- **Grafana**：Metrics / Logs / Traces 统一可视化（挂载 Prometheus/Loki/Tempo 数据源）。
- **Alertmanager**：接收 Prometheus 告警，分组、路由、通知（Email/Slack/Webhook）。
- **node-exporter**：节点系统指标（CPU/内存/磁盘/网络）。
- **kube-state-metrics**：把 K8s 对象状态转成 Metrics。

## 2. 部署位置 Location
- Namespace：`observability`
- Release：`kube-prometheus-stack`
- Chart：`prometheus-community/kube-prometheus-stack`
- 配置：`observability/kube-prometheus-stack/values.yaml`
- 子路径补丁：`ingress-nginx/observability-values-patch.yaml`（需合并进 values.yaml）

## 3. 安装 Start
```bash
cd observability/kube-prometheus-stack && chmod +x install.sh uninstall.sh
./install.sh
```
脚本：建 ns → 加 repo → `helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n observability -f values.yaml --wait --timeout 10m`。

## 4. 更新 Update
- 改 `values.yaml` 后，若涉及子路径（grafana/prometheus/alertmanager），先合并 `observability-values-patch.yaml`：
```bash
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n observability -f values.yaml --wait --timeout 10m
```

## 5. 停止 Stop
```bash
./uninstall.sh
# = helm uninstall kube-prometheus-stack -n observability + delete namespace observability
```

## 6. 挂起 / 恢复 Suspend / Resume
```bash
# 监控面全套缩到 0
kubectl scale deployment  -n observability kube-prometheus-stack-grafana --replicas=0
kubectl scale deployment  -n observability kube-prometheus-stack-operator --replicas=0
kubectl scale statefulset -n observability kube-prometheus-stack-prometheus --replicas=0
kubectl scale statefulset -n observability kube-prometheus-stack-alertmanager --replicas=0
# 恢复：把 0 改回 1
```

## 7. 健康检查 Health
```bash
kubectl get pods -n observability
kubectl get svc  -n observability
helm list -n observability
```

## 8. 访问 Access
| 组件 | Ingress Path | 直连 / port-forward |
| --- | --- | --- |
| Grafana | `http://localhost:30080/grafana/` | `kubectl port-forward -n observability svc/kube-prometheus-stack-grafana 3000:80` |
| Prometheus | `http://localhost:30080/prometheus/` | `kubectl port-forward -n observability svc/kube-prometheus-stack-prometheus 9090:9090` |
| Alertmanager | `http://localhost:30080/alertmanager/` | `kubectl port-forward -n observability svc/kube-prometheus-stack-alertmanager 9093:9093` |

账号：Grafana `admin / admin123456`。

## 9. 常见问题 Troubleshooting
- **Grafana 页面 404 / 资源加载异常**：子路径配置不一致。确认 `values.yaml` 中 `grafana.grafana.ini.server.root_url` 与 `serve_from_sub_path` 与 ingress `/grafana` 一致。
- **Prometheus 收不到指标**：检查 target 健康（`/prometheus` → Status → Targets）和 node-exporter/kube-state-metrics Pod 是否 Running。
- **告警不通知**：检查 Alertmanager 路由与 receiver 配置、以及 Prometheus 的 alerting rules。

## 10. 配置要点 Notes
- **子路径必须一致**：Prometheus/Alertmanager 的 `externalUrl` + `routePrefix`、Grafana 的 `root_url` 必须与 ingress path 完全对应，否则 404。
- **持久化**：Prometheus 当前**无 PVC（临时存储）**，重启/挂起丢历史数据；Grafana/Alertmanager 由 chart 默认可能带 PVC。长期保存需显式加 PVC + StorageClass。
- 旧 README 提到的 Grafana/Alertmanager 直连 NodePort 30030/30031 为历史残留，当前 `service.type: ClusterIP`，以 Ingress 30080 为准。
