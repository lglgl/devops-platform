# kube-prometheus-stack

Kubernetes 可观测性基础监控平台。

当前阶段部署：

```text
Prometheus
Grafana
Alertmanager
kube-state-metrics
node-exporter
Prometheus Operator
```

---

## 一、部署位置

组件统一部署到：

```text
namespace: observability
```

整体架构：

```text
Kubernetes
|
+-- ingress
|   +-- NGINX Ingress
|
+-- observability
|   +-- Prometheus
|   +-- Grafana
|   +-- Alertmanager
|   +-- kube-state-metrics
|   +-- node-exporter
|
+-- cicd
|   +-- Jenkins
|
+-- infra
|   +-- Redis
|   +-- PostgreSQL
|   +-- Kafka
|   +-- Registry
|
+-- app-*
```

---

## 二、目录

```text
kube-prometheus-stack/
|
+-- namespace.yaml
+-- values.yaml
+-- install.sh
+-- uninstall.sh
+-- README.md
```

---

## 三、组件关系

```text
                       Grafana
                          |
             +------------+------------+
             |                         |
             v                         v
        Prometheus                Alertmanager
             |
      +------+------+
      |             |
      v             v
node-exporter   kube-state-metrics
      |             |
      v             v
 Kubernetes Node   Kubernetes API
```

---

## 四、Prometheus

Prometheus 负责采集和保存 Metrics。

主要采集：

```text
Node
|
+-- CPU
+-- Memory
+-- Disk
+-- Network

Kubernetes
|
+-- Pod
+-- Deployment
+-- Service
+-- Namespace
+-- Node

Application
|
+-- HTTP Requests
+-- Error Rate
+-- Latency
```

---

## 五、Grafana

Grafana 用于可视化 Prometheus Metrics。

当前使用 NodePort：

```text
http://localhost:30030
```

默认账号：

```text
Username: admin
Password: admin123456
```

生产环境不要在 `values.yaml` 中明文保存密码。

---

## 六、Alertmanager

Alertmanager 负责接收 Prometheus Alert，并进行：

```text
Alert
 |
 v
Alertmanager
 |
 +-- Email
 +-- Slack
 +-- Webhook
 +-- 其他通知渠道
```

当前使用：

```text
http://localhost:30031
```

---

## 七、Node Exporter

Node Exporter 使用 DaemonSet。

每个 Kubernetes Node 一个 Pod：

```text
Node 1
  |
  +-- node-exporter

Node 2
  |
  +-- node-exporter

Node 3
  |
  +-- node-exporter
```

主要采集节点：

```text
CPU
Memory
Disk
Filesystem
Network
Load
```

---

## 八、kube-state-metrics

kube-state-metrics 读取 Kubernetes API，
将 Kubernetes 对象状态转换为 Prometheus Metrics。

例如：

```text
Deployment replicas
Pod status
Node status
DaemonSet status
StatefulSet status
Job status
PVC status
```

它关注的是 Kubernetes 对象的状态，而不是直接采集 Linux 系统指标。

---

## 九、安装

进入目录：

```bash
cd ~/devops-platform/observability/kube-prometheus-stack
```

执行：

```bash
chmod +x install.sh
./install.sh
```

---

## 十、检查

### 1. 查看 Pod

```bash
kubectl get pods -n observability
```

### 2. 查看 Service

```bash
kubectl get svc -n observability
```

### 3. 查看 Helm Release

```bash
helm list -n observability
```

应该看到：

```text
kube-prometheus-stack
```

---

## 十一、访问 Grafana

浏览器访问：

```text
http://localhost:30030
```

登录：

```text
Username:
admin

Password:
admin123456
```

进入 Grafana 后可以查看 kube-prometheus-stack 自带的 Kubernetes Dashboard。

---

## 十二、访问 Prometheus

Prometheus 默认不通过 NodePort 暴露。

使用 port-forward：

```bash
kubectl port-forward   -n observability   svc/kube-prometheus-stack-prometheus   9090:9090
```

然后访问：

```text
http://localhost:9090
```

---

## 十三、访问 Alertmanager

直接访问：

```text
http://localhost:30031
```

也可以使用 port-forward：

```bash
kubectl port-forward   -n observability   svc/kube-prometheus-stack-alertmanager   9093:9093
```

然后：

```text
http://localhost:9093
```

---

## 十四、当前数据链路

```text
Kubernetes
    |
    +-------------------+
    |                   |
    v                   v
node-exporter      kube-state-metrics
    |                   |
    +---------+---------+
              |
              v
         Prometheus
              |
       +------+------+
       |             |
       v             v
    Grafana      Alert Rules
                     |
                     v
                Alertmanager
```

---

## 十五、与 NGINX Ingress 的关系

当前阶段：

```text
Client
  |
  +--> :30030 --> Grafana
  |
  +--> :30031 --> Alertmanager
  |
  +--> :30080 --> NGINX Ingress
```

后续统一接入 NGINX Ingress 后：

```text
                    NGINX Ingress
                          |
          +---------------+---------------+
          |               |               |
          v               v               v
      Grafana           Jenkins          App
          |               |               |
   observability         cicd          app-prod
```

最终推荐：

```text
grafana.example.local
jenkins.example.local
api.example.local
app.example.local
```

---

## 十六、后续 Loki + Alloy

当前只建立 Metrics：

```text
Prometheus
    |
    v
Grafana
```

下一阶段加入 Logs：

```text
Kubernetes Pod
      |
      v
    Alloy
      |
      v
     Loki
      |
      v
   Grafana
```

最终 Grafana 统一查看：

```text
Metrics
  |
Prometheus
  |
  +----------------+
                   |
                   v
                 Grafana
                   ^
                   |
  +----------------+
  |
Logs
  |
Loki
  ^
  |
Alloy
```

再后续加入 Tempo：

```text
Metrics -> Prometheus
Logs    -> Loki
Traces  -> Tempo
             |
             v
          Grafana
```

形成完整 Observability Stack。

---

## 十七、卸载

执行：

```bash
./uninstall.sh
```

该操作会：

```text
卸载 kube-prometheus-stack
        |
        v
删除 observability Namespace
```

当前配置使用临时存储。

后续如果需要长期保存 Prometheus 数据，
再增加 PVC 和 StorageClass 配置。
