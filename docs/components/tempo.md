# Tempo 运维指导 · Operations

## 1. 功能 Function
分布式链路追踪（Tracing）后端（Grafana Labs）。接收应用经 OTLP 上报的 trace，存储后供 Grafana 通过 Tempo 数据源查询。本平台用原生 Kubernetes YAML 以**单体模式**部署。

## 2. 部署位置 Location
- Namespace：`observability`
- 镜像：`grafana/tempo:2.8.2`
- 目录：`observability/tempo/`
- Service `tempo`：
  - `http`  :3200（Query/API）
  - `otlp-grpc` :4317
  - `otlp-http` :4318
- 存储：PVC 10Gi（hostpath）

## 3. 安装 Start
```bash
cd observability/tempo && chmod +x install.sh uninstall.sh
./install.sh
```
脚本依次 apply：`tempo-config.yaml`(ConfigMap) → `tempo-pvc.yaml` → `tempo-deployment.yaml` → `tempo-service.yaml`。

## 4. 更新 Update
改配置后重新 apply 对应 YAML：
```bash
kubectl apply -f tempo-config.yaml -f tempo-deployment.yaml -f tempo-service.yaml
```

## 5. 停止 Stop
```bash
./uninstall.sh   # 删除 deployment/service/configmap，保留 PVC
# 确认无数据需保留后：kubectl delete pvc tempo-data -n observability
```

## 6. 挂起 / 恢复 Suspend / Resume
```bash
kubectl scale deployment tempo -n observability --replicas=0   # 挂起
kubectl scale deployment tempo -n observability --replicas=1   # 恢复
```

## 7. 健康检查 Health
```bash
kubectl get pods,svc,pvc -n observability
kubectl logs -n observability deployment/tempo --tail=100
kubectl port-forward -n observability svc/tempo 13200:3200
curl http://localhost:13200/ready   # 期望 "ready"
```

## 8. 访问 Access
- Query/API：`http://tempo.observability.svc.cluster.local:3200`
- OTLP 接收（应用上报）：
  - gRPC：`tempo.observability.svc.cluster.local:4317`
  - HTTP：`http://tempo.observability.svc.cluster.local:4318`
- Grafana 数据源 URL：`http://tempo.observability.svc.cluster.local:3200`

## 9. 常见问题 Troubleshooting
- **Grafana 看不到 trace**：确认应用已配置 OpenTelemetry SDK 并指向上面的 OTLP 地址；Tempo 本身不会自动生成 trace。
- **PVC 起不来**：确认 StorageClass `hostpath` 存在（`kubectl get storageclass`）。

## 10. 配置要点 Notes
- 单体模式非 HA；生产应设计对象存储、认证、TLS、保留策略与容量规划。
- 链路需应用侧埋点配合，部署 Tempo 只是后端。
