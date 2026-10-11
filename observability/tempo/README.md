# Grafana Tempo

Tempo 是分布式链路追踪后端。本目录使用原生 Kubernetes YAML，以单体模式部署至 `observability` 命名空间。

## 文件
- `tempo-config.yaml`：Tempo 配置 ConfigMap，接收 OTLP gRPC/HTTP。
- `tempo-pvc.yaml`：10Gi 持久化卷声明。
- `tempo-deployment.yaml`：Tempo 单副本 Deployment。
- `tempo-service.yaml`：集群内 Service。
- `install.sh` / `uninstall.sh`：安装和卸载脚本。

## 安装
从仓库根目录执行：
```bash
cd observability/tempo
chmod +x install.sh uninstall.sh
./install.sh
```

镜像为 `grafana/tempo:2.8.2`，PVC 使用 StorageClass `hostpath`，请确认该 StorageClass 存在并适用于当前集群。

## 验证
```bash
kubectl get pods,svc,pvc -n observability
kubectl logs -n observability deployment/tempo --tail=100
kubectl port-forward -n observability svc/tempo 13200:3200
```
访问 `http://localhost:13200/ready`，正常应返回 `ready`。

## Grafana 数据源
添加 Tempo 数据源，URL：
`http://tempo.observability.svc.cluster.local:3200`

OTLP 接收地址：
- gRPC：`tempo.observability.svc.cluster.local:4317`
- HTTP：`http://tempo.observability.svc.cluster.local:4318`

应用需另行配置 OpenTelemetry SDK、自动埋点或手动埋点；安装 Tempo 本身不会自动生成 Trace。

## 卸载
```bash
./uninstall.sh
```
卸载会保留 PVC，避免误删 Trace 数据。确认无需保留后，再执行：
```bash
kubectl delete pvc tempo-data -n observability
```

本配置适用于本地实验，不提供多副本高可用；生产环境应另行设计对象存储、认证、TLS、保留策略和容量规划。
