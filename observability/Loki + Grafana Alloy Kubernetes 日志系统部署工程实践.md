
# Loki + Grafana Alloy Kubernetes 日志系统部署工程实践

## 1. 项目背景

在 Kubernetes 环境中，Prometheus 主要负责采集 Metrics，而应用运行过程中产生的大量 stdout、stderr、容器日志以及系统日志，则需要独立的日志系统进行集中采集、存储、查询和分析。

本项目基于 Kubernetes 搭建一套轻量级日志系统：

```text
Kubernetes
    │
    │ Pod stdout / stderr
    ▼
Grafana Alloy
    │
    │ LogQL Push
    ▼
Loki
    │
    ▼
Grafana
```

其中：

* **Grafana Alloy**：负责发现 Kubernetes Pod、读取容器日志并进行处理和转发
* **Loki**：负责日志存储和查询
* **Grafana**：负责日志可视化、检索和 Dashboard
* **Kubernetes**：提供 Pod、Namespace、Container 等运行时元数据

本次部署环境：

```text
MacBook M4
24 GB RAM
Docker Desktop
Kubernetes
Helm
```

已有 Prometheus、Grafana、Alertmanager，因此 Loki 和 Alloy 直接接入现有 Observability Namespace。

---

# 2. 为什么选择 Loki + Alloy

传统 ELK/EFK 架构通常为：

```text
Fluent Bit
    ↓
Elasticsearch
    ↓
Kibana
```

或者：

```text
Fluentd
    ↓
Elasticsearch
    ↓
Kibana
```

这种架构功能完整，但是 Elasticsearch 对 CPU、内存和磁盘资源要求较高。

对于本地 Kubernetes、开发环境以及中小规模 Kubernetes 集群，可以采用：

```text
Alloy
  +
Loki
  +
Grafana
```

整体架构更加轻量。

Loki 的一个重要设计思想是：

> 不对所有日志正文建立完整全文索引，而主要依赖 Label 进行日志流组织和查询。

因此 Loki 的 Label 设计非常重要。

例如：

```text
cluster=docker-desktop
namespace=harbor
pod=harbor-portal-xxx
container=portal
```

查询时：

```logql
{namespace="harbor"}
```

再进行日志内容过滤：

```logql
{namespace="harbor"} |= "error"
```

---

# 3. 整体架构

最终架构设计如下：

```text
                         ┌─────────────────────┐
                         │      Grafana         │
                         │                     │
                         │ Metrics + Logs       │
                         └──────────┬──────────┘
                                    │
                         ┌──────────▼──────────┐
                         │        Loki          │
                         │                      │
                         │ Log Storage          │
                         │ LogQL Query          │
                         └──────────▲───────────┘
                                    │
                              HTTP Push
                                    │
                         ┌──────────┴───────────┐
                         │     Grafana Alloy    │
                         │                      │
                         │ Kubernetes Discovery │
                         │ Log Collection       │
                         │ Log Processing       │
                         │ Log Forwarding       │
                         └──────────▲───────────┘
                                    │
                ┌───────────────────┼───────────────────┐
                │                   │                   │
             Pod Logs            Pod Logs            Pod Logs
                │                   │                   │
             Harbor             Prometheus             Loki
```

本项目采用：

```text
Namespace: observability
```

将 Loki、Alloy、Prometheus、Grafana 等统一归入 Observability 平台。

---

# 4. Kubernetes StorageClass 注意事项

这是本次部署中非常重要的一个坑。

首先检查 StorageClass：

```bash
kubectl get storageclass
```

当前 Docker Desktop Kubernetes 环境实际使用的是：

```text
hostpath
```

并且：

```text
hostpath (default)
```

而不是很多教程中默认使用的：

```text
standard
```

因此 Loki PVC 必须使用：

```yaml
storageClass: hostpath
```

例如：

```yaml
singleBinary:
  persistence:
    enabled: true
    storageClass: hostpath
    accessModes:
      - ReadWriteOnce
    size: 10Gi
```

如果直接使用：

```yaml
storageClass: standard
```

而集群不存在 `standard`，PVC 会一直：

```text
Pending
```

并出现类似：

```text
storageclass.storage.k8s.io "standard" not found
```

因此部署任何 Stateful Service 前，建议首先确认：

```bash
kubectl get storageclass
```

---

# 5. Loki 部署

## 5.1 创建 Namespace

```bash
kubectl create namespace observability \
  --dry-run=client \
  -o yaml | kubectl apply -f -
```

如果 Namespace 已经存在，不需要重复创建。

---

# 6. 添加 Grafana Helm Repository

```bash
helm repo add grafana https://grafana.github.io/helm-charts

helm repo update
```

查看 Loki Chart：

```bash
helm search repo grafana/loki
```

---

# 7. Loki values.yaml

本项目使用 Monolithic 模式。

对于 Docker Desktop 本地 Kubernetes，这种部署方式比较适合。

完整配置：

```yaml
# Loki 使用单体模式。
# 本地开发环境只有一个 Kubernetes Node，
# 因此没有必要直接使用微服务模式部署多个 Loki 组件。
deploymentMode: Monolithic

loki:

  # 本项目不启用 Loki 多租户认证。
  # 本地实验环境直接使用单租户模式。
  auth_enabled: false

  commonConfig:

    # 当前只有一个 Loki 实例。
    replication_factor: 1

  schemaConfig:

    # Loki 使用 TSDB + filesystem。
    # 该方案适合本地 Kubernetes 实验环境。
    configs:

      - from: "2024-04-01"

        store: tsdb

        object_store: filesystem

        schema: v13

        index:
          prefix: loki_index_
          period: 24h

  storage:

    # 使用本地文件系统作为 Loki 存储。
    type: filesystem

  limits_config:

    # 支持结构化元数据。
    allow_structured_metadata: true

    # 启用 volume 查询能力。
    volume_enabled: true

  pattern_ingester:

    # 启用 Pattern Ingester。
    enabled: true


singleBinary:

  # 本地环境只运行一个 Loki Pod。
  replicas: 1

  persistence:

    # 开启持久化。
    enabled: true

    # Docker Desktop Kubernetes 实际 StorageClass。
    storageClass: hostpath

    accessModes:
      - ReadWriteOnce

    # Loki 日志存储容量。
    size: 10Gi


# 以下组件在 Monolithic 模式下关闭。
backend:
  replicas: 0

read:
  replicas: 0

write:
  replicas: 0

ingester:
  replicas: 0

querier:
  replicas: 0

queryFrontend:
  replicas: 0

queryScheduler:
  replicas: 0

distributor:
  replicas: 0

compactor:
  replicas: 0

indexGateway:
  replicas: 0

bloomPlanner:
  replicas: 0

bloomBuilder:
  replicas: 0

bloomGateway:
  replicas: 0


# 本项目不额外部署 Loki Gateway。
gateway:
  enabled: false


# 不使用 Loki Chart 自带 MinIO。
minio:
  enabled: false


# 本地实验环境关闭缓存组件。
chunksCache:
  enabled: false

resultsCache:
  enabled: false


# Helm Test 需要 Canary。
lokiCanary:
  enabled: true
```

保存为：

```text
loki/values.yaml
```

---

# 8. 安装 Loki

执行：

```bash
helm upgrade --install loki grafana/loki \
  --namespace observability \
  --create-namespace \
  -f values.yaml
```

查看 Helm：

```bash
helm list -n observability
```

查看 Pod：

```bash
kubectl get pods -n observability
```

正常情况下可以看到：

```text
loki-0
loki-canary-xxxx
```

检查 PVC：

```bash
kubectl get pvc -n observability
```

应该类似：

```text
NAME           STATUS   VOLUME
storage-loki-0 Bound    ...
```

---

# 9. 验证 Loki API

进入临时测试 Pod：

```bash
kubectl run loki-query \
  -n observability \
  --rm -it \
  --restart=Never \
  --image=curlimages/curl \
  -- sh
```

测试 Loki：

```bash
curl http://loki:3100/ready
```

如果返回：

```text
ready
```

说明 Loki 已经正常启动。

---

# 10. 测试 Loki 写入

生成 Unix 时间戳：

```bash
NOW=$(date +%s)000000000
```

写入测试日志：

```bash
curl \
  -H "Content-Type: application/json" \
  -XPOST \
  -s \
  "http://loki:3100/loki/api/v1/push" \
  --data-raw \
  "{\"streams\":[{\"stream\":{\"job\":\"loki-test\"},\"values\":[[\"$NOW\",\"hello from loki\"]]}]}"
```

查询：

```bash
curl -G -s \
  "http://loki:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="loki-test"}'
```

如果能够返回：

```text
hello from loki
```

说明：

```text
Loki API
   ↓
写入
   ↓
存储
   ↓
查询
```

整个链路正常。

---

# 11. 为什么需要 Grafana Alloy

Loki 本身不是 Kubernetes 日志采集器。

Loki 负责：

```text
Storage
Query
LogQL
```

而 Alloy 负责：

```text
Discovery
Collection
Processing
Forwarding
```

因此：

```text
Kubernetes
      ↓
    Alloy
      ↓
     Loki
      ↓
   Grafana
```

是比较清晰的职责划分。

---

# 12. 安装 Alloy

添加 Grafana Helm Repository：

```bash
helm repo add grafana https://grafana.github.io/helm-charts

helm repo update
```

检查：

```bash
helm search repo grafana/alloy
```

---

# 13. Alloy values.yaml

这里有一个非常重要的工程注意事项：

**不要手工创建 ServiceAccount、ClusterRole 和 ClusterRoleBinding，再让 Helm Chart 创建同名资源。**

否则 Helm 会出现：

```text
invalid ownership metadata
```

正确方式是：

> RBAC 由 Helm Chart 统一管理。

完整配置：

```yaml
# Alloy Controller 使用 Deployment。
controller:

  type: deployment

  replicas: 1


# ServiceAccount 由 Helm 创建和管理。
serviceAccount:

  create: true

  name: alloy-logs


alloy:

  # 本项目只有一个 Alloy 实例。
  # 本地环境不需要 Alloy Clustering。
  clustering:
    enabled: false


  configMap:

    # 让 Helm 创建 ConfigMap。
    create: true

    # Alloy River 配置。
    content: |

      // Alloy 自身日志配置。
      logging {
        level  = "info"
        format = "logfmt"
      }


      // 从 Kubernetes API 自动发现 Pod。
      discovery.kubernetes "pods" {

        role = "pod"
      }


      // 从 Kubernetes Pod 获取日志。
      loki.source.kubernetes "pods" {

        targets = discovery.kubernetes.pods.targets

        forward_to = [
          loki.process.pods.receiver,
        ]
      }


      // 日志处理阶段。
      loki.process "pods" {

        forward_to = [
          loki.write.loki.receiver,
        ]


        // 给所有日志增加统一的集群标签。
        stage.static_labels {

          values = {

            cluster = "docker-desktop"

          }
        }
      }


      // 将日志写入 Loki。
      loki.write "loki" {

        endpoint {

          url = "http://loki.observability.svc.cluster.local:3100/loki/api/v1/push"
        }
      }
```

---

# 14. Alloy 配置中的一个重要坑

Alloy 使用的是：

```text
River
```

配置语言。

注释应该使用：

```text
//
```

例如：

```text
// This is a comment
```

而不能写成：

```text
# This is a comment
```

否则 Alloy 会报：

```text
expected identifier, got ILLEGAL
```

甚至可能出现：

```text
illegal character U+0023 '#'
```

因此不要把 Prometheus、YAML 或 Shell 中的注释习惯直接复制到 Alloy River 配置中。

---

# 15. 安装 Alloy

执行：

```bash
helm upgrade --install alloy-logs grafana/alloy \
  --namespace observability \
  --create-namespace \
  -f values.yaml
```

检查：

```bash
kubectl get pods -n observability \
  -l app.kubernetes.io/name=alloy
```

正常：

```text
alloy-logs-xxxx   2/2   Running
```

查看日志：

```bash
kubectl logs \
  -n observability \
  -l app.kubernetes.io/name=alloy \
  --tail=100
```

---

# 16. Alloy + Loki 的第一阶段验证

不要一开始就创建复杂的 Label、Pipeline 和过滤规则。

首先创建最简单的测试 Pod：

```bash
kubectl run log-test \
  -n observability \
  --image=busybox:1.36 \
  --restart=Never \
  -- sh -c '
    i=0
    while true
    do
      echo "alloy-test message=$i"
      i=$((i+1))
      sleep 5
    done
  '
```

检查 Pod：

```bash
kubectl get pod -n observability log-test
```

检查原始日志：

```bash
kubectl logs -n observability log-test
```

应该看到：

```text
alloy-test message=0
alloy-test message=1
alloy-test message=2
```

---

# 17. 查询 Loki

启动临时客户端：

```bash
kubectl run loki-query \
  -n observability \
  --rm -it \
  --restart=Never \
  --image=curlimages/curl \
  -- sh
```

查询：

```bash
curl -G -s \
  "http://loki:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={cluster="docker-desktop"}'
```

本次实际部署中已经成功查询到了：

```text
alloy-test message=2
alloy-test message=3
```

同时还能看到：

```text
Harbor
Loki
Prometheus
Alloy
node-exporter
```

等 Kubernetes Pod 的日志。

这证明：

```text
Pod
 ↓
Kubernetes Discovery
 ↓
Alloy
 ↓
Loki
 ↓
LogQL
```

完整链路已经打通。

---

# 18. Alloy 实际采集到了什么

当前查询结果中已经可以看到多个 Namespace。

例如：

```text
observability
harbor
```

同时存在：

```text
harbor-nginx
harbor-portal
harbor-registry
loki
loki-sc-rules
log-test
node-exporter
```

例如 Harbor 日志：

```text
harbor/harbor-portal-xxxx:portal
```

能够被 Loki 查询到。

这说明 Alloy 的：

```text
discovery.kubernetes
```

已经能够自动发现 Kubernetes Pod。

---

# 19. Kubernetes 日志采集的核心机制

当前架构可以理解为：

```text
Kubernetes API
       │
       ▼
discovery.kubernetes
       │
       ▼
Pod Targets
       │
       ▼
loki.source.kubernetes.pods
       │
       ▼
Container Logs
       │
       ▼
loki.process
       │
       ▼
loki.write
       │
       ▼
Loki
```

其中：

### Discovery

负责知道：

```text
有哪些 Pod
有哪些 Container
Pod 属于哪个 Namespace
Pod 当前在哪里运行
```

### Source

负责：

```text
读取 Kubernetes Pod 日志
```

### Process

负责：

```text
Label
Filter
Parse
Transform
Drop
```

### Write

负责：

```text
HTTP Push → Loki
```

这种设计比单纯写一个日志采集脚本更加适合 Kubernetes。

---

# 20. 为什么不建议一开始配置大量 Label

Loki 的 Label 和 Elasticsearch 的索引概念不同。

不要把：

```text
request_id
user_id
timestamp
trace_id
session_id
```

等高基数字段全部作为 Label。

例如：

```text
user_id=123456
user_id=123457
user_id=123458
```

会导致 Label Cardinality 快速增长。

更适合作为 Label 的是：

```text
cluster
namespace
pod
container
app
job
environment
```

例如：

```text
cluster=docker-desktop
namespace=harbor
app=registry
container=registry
```

然后正文中再查询：

```logql
{namespace="harbor"} |= "error"
```

---

# 21. 第二阶段：增加 Kubernetes Label

在第一阶段确认日志链路稳定以后，再增加：

```text
namespace
pod
container
app
```

最终希望得到：

```text
cluster="docker-desktop"
namespace="harbor"
pod="harbor-portal-xxx"
container="portal"
```

这样 Grafana Explore 就可以实现：

```logql
{namespace="harbor"}
```

或者：

```logql
{namespace="harbor", container="registry"}
```

再进行内容过滤：

```logql
{namespace="harbor"} |= "error"
```

---

# 22. Grafana 接入 Loki

Loki 的 Kubernetes Service：

```text
loki.observability.svc.cluster.local
```

端口：

```text
3100
```

Grafana Datasource URL：

```text
http://loki.observability.svc.cluster.local:3100
```

Grafana：

```text
Connections
    ↓
Data Sources
    ↓
Add data source
    ↓
Loki
```

填写：

```text
URL:

http://loki.observability.svc.cluster.local:3100
```

然后：

```text
Save & Test
```

---

# 23. Grafana Explore 基础查询

连接成功后进入：

```text
Explore
```

选择 Loki。

最基础：

```logql
{cluster="docker-desktop"}
```

查询错误：

```logql
{cluster="docker-desktop"} |= "error"
```

查询 Harbor：

```logql
{namespace="harbor"}
```

查询 Loki：

```logql
{namespace="observability", pod=~"loki.*"}
```

查询特定容器：

```logql
{namespace="harbor", container="registry"}
```

---

# 24. 当前环境出现的两个日志问题

## 24.1 etcd revision compacted

查询结果中出现：

```text
watch chan error:
etcdserver: mvcc: required revision has been compacted
```

这类信息来自 Kubernetes API Watch。

它说明 Alloy 的 Kubernetes Discovery 在 Watch 过程中遇到了已经被 etcd compact 掉的历史 revision。

对于本地 Docker Desktop Kubernetes，这类日志不一定意味着 Loki 或 Alloy 故障。

关键是观察：

```text
Alloy Pod
Loki Pod
日志采集
```

是否持续正常。

当前测试中 Alloy 仍然持续发现和打开日志流，因此日志链路本身是工作的。

---

# 25. node-exporter 日志文件不存在

当前日志中还有：

```text
failed to try resolving symlinks in path
/var/log/pods/...
```

以及：

```text
lstat ... no such file or directory
```

这说明 Alloy 尝试读取某个已经不存在的 Pod 日志文件。

尤其当前环境中的：

```text
kube-prometheus-stack-prometheus-node-exporter
```

Pod 本身此前存在：

```text
CrashLoopBackOff
```

因此会产生：

```text
日志文件创建
        ↓
Pod 重启
        ↓
旧日志文件删除
        ↓
Alloy 仍处理旧 Target
        ↓
文件不存在
```

所以这里应该：

**优先解决 node-exporter 本身的问题，而不是修改 Loki。**

---

# 26. 不要把所有日志问题都归因于 Loki

排查日志系统时建议按照以下层级：

```text
第一层
Kubernetes Pod 是否正常

        ↓

第二层
kubectl logs 是否正常

        ↓

第三层
Alloy 是否发现 Pod

        ↓

第四层
Alloy 是否读取日志

        ↓

第五层
Alloy 是否 Push Loki

        ↓

第六层
Loki 是否存储

        ↓

第七层
Loki Query 是否能够返回

        ↓

第八层
Grafana 是否能够查询
```

例如：

```bash
kubectl logs POD
```

都没有日志，那么不要去查 Loki。

如果：

```bash
kubectl logs POD
```

正常，但是 Loki 查询不到，那么才开始检查：

```text
Alloy
```

---

# 27. Helm 管理 RBAC 的注意事项

这是本次部署中另一个重要问题。

错误：

```text
ClusterRole "alloy-logs"
invalid ownership metadata
```

以及：

```text
ServiceAccount "alloy-logs"
invalid ownership metadata
```

原因是：

```text
手工创建 RBAC
        +
Helm Chart 创建同名 RBAC
```

两个管理者冲突。

正确方法：

```text
Helm
 │
 ├── ServiceAccount
 ├── ClusterRole
 └── ClusterRoleBinding
```

统一交给 Helm 管理。

因此部署 Alloy 时：

**不要同时执行自定义 `rbac.yaml`。**

检查资源：

```bash
kubectl get serviceaccount -n observability
```

```bash
kubectl get clusterrole | grep alloy
```

```bash
kubectl get clusterrolebinding | grep alloy
```

---

# 28. PVC 修改注意事项

Kubernetes PVC 的：

```text
storageClassName
```

不是随便可以修改的。

例如已经创建：

```text
storageClassName: standard
```

之后再修改成：

```text
storageClassName: hostpath
```

可能会遇到：

```text
spec is immutable
```

正确方式通常是：

```text
删除错误 PVC
        ↓
修正 values.yaml
        ↓
重新 Helm Upgrade
        ↓
重新创建 PVC
```

但是如果已经存在真实生产数据，则不能直接删除 PVC。

生产环境必须先考虑：

```text
Backup
Snapshot
Migration
Data Recovery
```

---

# 29. 本地环境与生产环境的区别

当前方案：

```text
Loki
 └── filesystem
      └── hostpath
```

适合：

```text
开发环境
学习环境
个人实验室
Portfolio
小型测试集群
```

但生产环境通常不建议把 Loki 数据直接依赖单节点本地文件系统。

生产环境更适合：

```text
Alloy
   ↓
Loki
   ↓
Object Storage
   ↓
S3 / MinIO / GCS / Azure Blob
```

例如：

```text
                    ┌── Loki
                    │
Alloy ──────────────┤
                    │
                    └── Object Storage
                           │
                           ├── S3
                           ├── MinIO
                           └── Azure Blob
```

这样可以提高：

```text
持久性
扩展性
可恢复性
```

---

# 30. Loki 数据生命周期

日志系统不能只考虑：

```text
怎么采集
```

还必须考虑：

```text
保存多久
```

例如：

```text
开发环境
7 天

测试环境
14 天

生产环境
30～90 天
```

具体保留周期应该根据：

```text
业务
合规
审计
成本
安全要求
```

决定。

---

# 31. Loki 性能优化原则

Loki 的核心优化原则不是：

```text
无限增加 Label
```

而是：

```text
控制 Label Cardinality
```

例如推荐：

```text
cluster
namespace
app
container
environment
```

谨慎使用：

```text
pod
```

大量动态 Pod 名称可能增加 Stream 数量。

禁止或者谨慎：

```text
request_id
user_id
trace_id
session_id
```

作为 Label。

这些字段更适合留在日志正文中。

---

# 32. 日志过滤

对于大量无意义日志，可以在 Alloy 中处理。

例如：

```text
Kubernetes
     ↓
Alloy
     ↓
Filter
     ↓
Loki
```

可以减少：

```text
网络流量
Loki 存储
查询数据量
磁盘占用
```

但是过滤必须谨慎。

不要在采集端随意丢掉：

```text
error
warning
security
audit
authentication
authorization
```

等关键日志。

---

# 33. 日志系统排障命令

## 查看 Alloy

```bash
kubectl get pods -n observability \
  -l app.kubernetes.io/name=alloy
```

查看日志：

```bash
kubectl logs \
  -n observability \
  -l app.kubernetes.io/name=alloy \
  --tail=100
```

---

## 查看 Loki

```bash
kubectl get pods -n observability \
  -l app.kubernetes.io/name=loki
```

查看日志：

```bash
kubectl logs \
  -n observability \
  loki-0 \
  --tail=100
```

---

## 查看 PVC

```bash
kubectl get pvc -n observability
```

---

## 查看 StorageClass

```bash
kubectl get storageclass
```

---

## 查看 Pod 日志

```bash
kubectl logs -n NAMESPACE POD
```

---

## 测试 Loki

```bash
curl http://loki:3100/ready
```

查询：

```bash
curl -G -s \
  "http://loki:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={cluster="docker-desktop"}'
```

---

# 34. 推荐的工程目录

最终可以把项目整理成：

```text
observability/
│
├── README.md
│
├── loki/
│   ├── values.yaml
│   └── install.sh
│
├── alloy/
│   ├── values.yaml
│   └── install.sh
│
├── grafana/
│   ├── datasources/
│   └── dashboards/
│
├── prometheus/
│   └── values.yaml
│
└── scripts/
    ├── health-check.sh
    └── cleanup.sh
```

推荐将每个组件的部署方式固定下来：

```text
helm
 ↓
values.yaml
 ↓
install.sh
 ↓
health-check.sh
```

避免大量手工执行命令。

---

# 35. 最终完整架构

当前 Observability 平台可以逐渐形成：

```text
                         Grafana
                            │
             ┌──────────────┴──────────────┐
             │                             │
          Prometheus                       Loki
             │                             │
          Metrics                         Logs
             │                             │
             │                           Alloy
             │                             │
             │                Kubernetes Pod Logs
             │                             │
             └──────────────┬──────────────┘
                            │
                       Kubernetes
                            │
          ┌─────────────────┼─────────────────┐
          │                 │                 │
        Harbor             Jenkins           Apps
          │                 │                 │
        Redis              Kafka          PostgreSQL
```

未来还可以继续加入：

```text
Tempo
  ↓
Distributed Tracing
```

形成：

```text
Metrics
   ↓
Prometheus

Logs
   ↓
Loki + Alloy

Traces
   ↓
Tempo

Visualization
   ↓
Grafana
```

最终形成完整的：

```text
Observability
    │
    ├── Metrics
    │
    ├── Logs
    │
    ├── Traces
    │
    └── Alerting
```

---

# 36. 本次部署的关键经验总结

### 经验一：先确认 StorageClass

不要默认认为 Kubernetes 一定存在：

```text
standard
```

先执行：

```bash
kubectl get storageclass
```

本地 Docker Desktop 环境实际可能是：

```text
hostpath
```

---

### 经验二：Loki 先做最小化部署

本地 Kubernetes 不需要一开始就：

```text
Distributed Loki
MinIO
多个 Backend
多个 Read
多个 Write
多个 Gateway
```

先使用：

```text
Monolithic
+
filesystem
+
1 Replica
```

把：

```text
Push
Storage
Query
```

跑通以后再扩展。

---

### 经验三：Alloy 先保证日志链路

第一阶段只验证：

```text
Pod
 ↓
Alloy
 ↓
Loki
```

不要一开始就加入大量：

```text
Label
Parser
Regex
Multiline
Filter
```

否则出问题时很难定位。

---

### 经验四：RBAC 只保留一个管理者

如果使用 Helm：

```text
Helm 管理 RBAC
```

就不要再：

```text
kubectl apply -f rbac.yaml
```

否则非常容易出现 Helm ownership 冲突。

---

### 经验五：Alloy 使用 River

Alloy 配置：

```text
River
```

注释：

```text
//
```

不是：

```text
#
```

这是实际部署过程中非常容易踩的语法问题。

---

### 经验六：先解决 Kubernetes 本身的问题

如果：

```text
Pod CrashLoopBackOff
```

那么 Alloy 采集到的日志可能出现：

```text
旧日志文件不存在
Pod target 变化
日志文件重复打开
```

因此：

```text
应用问题
```

和：

```text
日志系统问题
```

必须分开判断。

---

# 37. 验收标准

Loki + Alloy 部署完成后，至少应该通过以下测试：

```text
[✓] Loki Pod Running

[✓] Loki PVC Bound

[✓] Loki /ready 正常

[✓] Loki Push API 正常

[✓] Loki Query API 正常

[✓] Alloy Pod Running

[✓] Alloy 能发现 Kubernetes Pod

[✓] Alloy 能读取 Pod 日志

[✓] Alloy 能 Push Loki

[✓] Loki 能查询 Alloy 采集的日志

[✓] Grafana 能连接 Loki

[✓] Grafana Explore 能查询日志
```

本次实际测试已经验证了其中最核心的：

```text
Alloy
  ↓
Kubernetes Pod Discovery
  ↓
Pod Logs
  ↓
Loki
  ↓
LogQL
```

并且已经成功查询到测试 Pod、Harbor、Loki、Prometheus 等多个组件日志。

---

# 38. 后续建设路线

建议按照以下顺序继续完善：

```text
阶段 1
Loki + Alloy
        ✓

阶段 2
Kubernetes Metadata Labels
        ↓

namespace
pod
container
app

阶段 3
Grafana Loki Datasource
        ↓
Explore

阶段 4
Loki Dashboard
        ↓
Error
Warning
Log Rate
Top Namespace

阶段 5
Log Alerting
        ↓
Loki
        ↓
Alertmanager

阶段 6
Tempo
        ↓
Distributed Tracing

阶段 7
OpenTelemetry
        ↓
Metrics + Logs + Traces

阶段 8
统一 Observability Platform
```

最终形成：

```text
                 Grafana
                    │
       ┌────────────┼────────────┐
       │            │            │
   Prometheus      Loki         Tempo
       │            │            │
    Metrics       Logs        Traces
                    │
                  Alloy
                    │
               Kubernetes
```

这套架构已经可以作为一个完整的 **DevOps / SRE Observability 实践项目**。
