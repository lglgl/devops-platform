# Loki 运维指导 · Operations

## 1. 功能 Function
日志存储后端（Grafana Labs）。接收 Alloy 推送的日志，供 Grafana 通过 Loki 数据源查询（LogQL）。当前为**单体（monolithic）+ filesystem** 模式。

## 2. 部署位置 Location
- Namespace：`observability`
- Release：`loki`
- Chart：`grafana-community/loki`
- 配置：`observability/loki/values.yaml`
- Service：`loki.observability.svc.cluster.local:3100`（ClusterIP，集群内）
- 存储：PVC 10Gi（hostpath）

## 3. 安装 Start
```bash
cd observability/loki && chmod +x install.sh uninstall.sh
./install.sh
```
脚本：建 ns → 加 `grafana-community` repo → `helm upgrade --install loki grafana-community/loki -n observability -f values.yaml`。

## 4. 更新 Update
```bash
helm upgrade --install loki grafana-community/loki -n observability -f values.yaml
```

## 5. 停止 Stop
```bash
helm uninstall loki -n observability
# PVC 默认保留（避免误删日志）
```

## 6. 挂起 / 恢复 Suspend / Resume
```bash
kubectl scale deployment loki -n observability --replicas=0   # 挂起
kubectl scale deployment loki -n observability --replicas=1   # 恢复
```

## 7. 健康检查 Health
```bash
kubectl get pods -n observability -l app.kubernetes.io/name=loki
kubectl get pvc  -n observability
# readiness
kubectl run loki-test -n observability --rm -it --restart=Never \
  --image=curlimages/curl -- curl -s http://loki:3100/ready   # 期望 "ready"
```

## 8. 访问 Access
- 集群内：`http://loki.observability.svc.cluster.local:3100`
- 外部查询：Grafana → Explore → Loki（数据源 URL 即上面的集群地址）
- 调试转发：`kubectl port-forward -n observability svc/loki 3100:3100`

## 9. 常见问题 Troubleshooting
- **Grafana 连不上 Loki**：数据源 URL 必须用集群 Service 地址（`http://loki.observability.svc.cluster.local:3100`），不要用 `localhost:30080/loki`（Grafana Pod 内部解析不到）。
- **收不到日志**：先确认 Alloy 正常（见 alloy 文档），再查 Loki readiness。
- **磁盘占满**：单体模式单 PVC，注意保留期（retention）配置。

## 10. 配置要点 Notes
- 当前单体非 HA；后续可升级为 **Distributed + S3/MinIO**。
- PVC 10Gi 仅为本地 Lab；生产需容量规划与对象存储。
