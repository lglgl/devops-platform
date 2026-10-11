# Loki + Alloy

适用于：

- MacBook M4
- Docker Desktop Kubernetes
- kube-prometheus-stack
- Grafana
- Prometheus
- NGINX Ingress

## 架构

```text
Kubernetes Pods
      |
      | stdout / stderr
      v
Kubernetes API
      |
      v
Alloy
      |
      | Loki Push API
      v
Loki
      |
      v
Grafana
      |
      v
Explore / Logs
```

## 1. 安装 Loki

```bash
cd loki-alloy/loki
chmod +x install.sh uninstall.sh
./install.sh
```

检查：

```bash
kubectl get pods -n observability
kubectl get pvc -n observability
kubectl get svc -n observability
```

Loki 服务：

```text
loki.observability.svc.cluster.local:3100
```

## 2. 安装 Alloy

```bash
cd ../alloy
chmod +x install.sh uninstall.sh
./install.sh
```

检查：

```bash
kubectl get pods -n observability -l app.kubernetes.io/name=alloy-logs
kubectl logs -n observability -l app.kubernetes.io/name=alloy-logs --tail=100
```

## 3. 验证 Loki

先检查 Loki Pod：

```bash
kubectl get pods -n observability | grep loki
```

测试 Loki readiness：

```bash
kubectl run loki-test \
  -n observability \
  --rm -it \
  --restart=Never \
  --image=curlimages/curl \
  -- curl -s http://loki:3100/ready
```

正常应该返回：

```text
ready
```

## 4. Grafana 添加 Loki Data Source

进入：

```text
http://localhost:30080/grafana/
```

进入：

```text
Connections
  ->
Data sources
  ->
Add data source
  ->
Loki
```

URL：

```text
http://loki.observability.svc.cluster.local:3100
```

不要使用：

```text
http://localhost:30080/loki
```

因为 Grafana Pod 访问 Loki 时，应该使用 Kubernetes Service。

点击：

```text
Save & test
```

看到：

```text
Data source connected
```

即可。

## 5. Grafana Explore 查询

进入：

```text
Explore
```

选择：

```text
Loki
```

先查询：

```logql
{cluster="docker-desktop"}
```

然后：

```logql
{namespace="observability"}
```

查看 Grafana：

```logql
{namespace="observability", container=~".*grafana.*"}
```

查看 Jenkins：

```logql
{namespace="cicd"}
```

如果 Jenkins 还没有部署，则不会有结果。

查看所有 namespace：

```logql
{namespace=~".+"}
```

## 6. 生成测试日志

创建一个持续输出日志的 Pod：

```bash
kubectl run log-test \
  -n observability \
  --image=busybox:1.36 \
  --restart=Never \
  -- sh -c 'i=0; while true; do echo "loki-test message=$i timestamp=$(date -Iseconds)"; i=$((i+1)); sleep 5; done'
```

检查：

```bash
kubectl logs -n observability log-test
```

然后 Grafana Explore：

```logql
{namespace="observability", pod="log-test"}
```

应该可以看到：

```text
loki-test message=0
loki-test message=1
loki-test message=2
...
```

测试完成后删除：

```bash
kubectl delete pod log-test -n observability
```

## 7. Alloy 排错

查看 Pod：

```bash
kubectl get pods -n observability -l app.kubernetes.io/name=alloy-logs
```

查看日志：

```bash
kubectl logs -n observability \
  -l app.kubernetes.io/name=alloy-logs \
  --tail=200
```

查看 Alloy 配置：

```bash
kubectl get configmap -n observability alloy-logs -o yaml
```

查看 RBAC：

```bash
kubectl get clusterrole alloy-logs
kubectl get clusterrolebinding alloy-logs
kubectl get serviceaccount alloy-logs -n observability
```

## 8. Loki 排错

```bash
kubectl get pods -n observability | grep loki
kubectl logs -n observability -l app.kubernetes.io/name=loki --tail=200
kubectl get pvc -n observability
```

测试：

```bash
kubectl run loki-test \
  -n observability \
  --rm -it \
  --restart=Never \
  --image=curlimages/curl \
  -- curl -s http://loki:3100/ready
```

## 9. 当前版本的设计取舍

这是本地 SRE Lab 版本：

```text
Loki
  Monolithic
  1 replica
  filesystem
  10Gi PVC

Alloy
  Deployment
  1 replica
  Kubernetes API
```

这个版本的目的不是 HA，而是先把：

```text
Pod Logs
   ↓
Alloy
   ↓
Loki
   ↓
Grafana
```

完整跑通。

后续进入更接近生产的架构时，再升级：

```text
Loki Distributed
        +
S3 / MinIO
        +
Alloy DaemonSet
        +
Kubernetes Events
        +
Log parsing
        +
Alerting
```
