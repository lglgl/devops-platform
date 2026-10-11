================================================================================
 SRE Platform · 组件关系连接图 & 表格 (readme-relationship.txt)
 平台: Docker Desktop Kubernetes (docker-desktop, v1.32.2, 单节点, MacBook Pro M4)
 统一入口: http://localhost:30080/  |  HTTPS: 30443 (未启用证书)
================================================================================

--------------------------------------------------------------------------------
 1. 总体架构连接图 (Overall Architecture)
--------------------------------------------------------------------------------

                                ┌──────────────────────────────┐
                                │        MacBook 浏览器         │
                                └──────────────┬───────────────┘
                                               │ http://localhost:30080
                                               ▼
                          ┌────────────────────────────────────────┐
                          │  ingress-nginx  (ns: ingress)          │
                          │  NodePort 30080 / 30443                │
                          │  IngressClass: nginx (default)         │
                          └───┬──────┬──────┬──────┬──────┬─────────┘
                              │      │      │      │      │
              path 按长度优先匹配▼      ▼      ▼      ▼      ▼
        /  │ /grafana │ /prometheus │ /alertmanager │ /jenkins │ /argocd
           │          │             │               │          │
           ▼          ▼             ▼               ▼          ▼
   ┌────────────┐ ┌────────┐  ┌────────────┐  ┌─────────┐ ┌─────────┐
   │ platform-  │ │Grafana │  │ Prometheus │  │ Jenkins │ │ Argo CD │
   │ dashboard  │ │  :80   │  │   :9090    │  │  :8080  │ │  :80    │
   │ (首页) :80 │ │        │  │            │  │         │ │         │
   └────────────┘ └────────┘  └────────────┘  └─────────┘ └─────────┘
   ns:observability  (Grafana/Prometheus/Alertmanager 同 ns: observability)
                                     (Jenkins/ArgoCD 同 ns: cicd)

   注: K8s 要求 Ingress 与 backend Service 同 namespace。
       observability ns 的 Ingress(observability) 承载 / /grafana /prometheus /alertmanager
       cicd ns 的 Ingress(cicd-ingress) 承载 /jenkins /argocd

--------------------------------------------------------------------------------
 2. 可观测性数据链路 (Observability Data Flows)
--------------------------------------------------------------------------------

 [Metrics 指标链路]
   Kubernetes Node ──► node-exporter (DaemonSet :9100) ──┐
   Kubernetes API  ──► kube-state-metrics (:8080)      ──┤
                                                         ▼
                                                    Prometheus (:9090)
                                                    (scrape, 存储, PromQL, 告警规则)
                                                     │              │
                                              数据源 ▼               ▼ 告警
                                              Grafana (:80)    Alertmanager (:9093)
                                                               │
                                                               ▼
                                                     通知 (Email/Slack/Webhook)

 [Logs 日志链路]
   Pods stdout/stderr ──► Kubernetes API ──► Alloy (Deployment, watch+采集)
                                               │ Loki Push API
                                               ▼
                                          Loki :3100 (单体, PVC 10Gi)
                                               │ 数据源
                                               ▼
                                            Grafana (Explore → LogQL)

 [Traces 链路追踪]
   应用 (OTLP SDK 埋点) ──► Tempo :4317 (gRPC) / :4318 (HTTP)
                               │ 存储 (PVC 10Gi)
                               ▼
                        Tempo :3200 (Query/API) ──► Grafana 数据源

 [统一可视化] Grafana 同挂 3 个数据源: Prometheus(:9090) + Loki(:3100) + Tempo(:3200)
              = Metrics + Logs + Traces 一个页面查全

--------------------------------------------------------------------------------
 3. CICD / GitOps 链路 (Build & Deploy Flow)
--------------------------------------------------------------------------------

   开发者 ──► Git 仓库 ────────────────┐
                │                      │ (Git 为唯一事实源)
                ▼                      ▼
   ┌────────────────┐        ┌──────────────────┐
   │ Jenkins (cicd) │  build │  Argo CD (cicd)  │
   │ Controller:8080│ ─────► │ 监听 Git → diff  │
   │ numExecutors=0 │  push  │ → sync 到 K8s    │
   └───────┬────────┘  image │(自动/手动)        │
           │ K8s Plugin      └────────┬─────────┘
           ▼                          │ apply
   临时 Agent Pod (动态创建,           ▼
   podRetention=Never, cap=3)   业务应用 (app-sample ns)
           │                          ▲
           └── 构建完成自动删除 ──      │ 部署
                                      │
   Registry (infra, :5000) ◄─── 镜像拉取 (规划/骨架已建)
   http://localhost:30080/registry/

--------------------------------------------------------------------------------
 4. 组件清单表 (Component Inventory)
--------------------------------------------------------------------------------
 组件                    | Namespace    | 类型/Chart              | 副本 | 持久化
 ------------------------+--------------+-------------------------+------+----------
 ingress-nginx           | ingress      | Helm 4.15.1             | 1    | -
 kube-prometheus-stack   | observability| Helm 91.8.2             | 各1  | 无PVC(临时)
   ├ Prometheus          | observability| (operator管理)          | 1    | 无(重启丢数据)
   ├ Grafana             | observability| (同Release)             | 1    | chart默认
   ├ Alertmanager        | observability| (同Release)             | 1    | chart默认
   ├ node-exporter       | observability| DaemonSet               | 1    | -
   ├ kube-state-metrics  | observability| Deployment              | 1    | -
   └ prometheus-operator | observability| Deployment              | 1    | -
 loki                    | observability| Helm 18.15.1 (3.7.8)    | 1    | PVC 10Gi
 alloy-logs              | observability| Helm 1.13.0 (v1.20.0)   | 1    | -
 tempo                   | observability| 原生YAML (2.8.2)        | 1    | PVC 10Gi
 platform-dashboard      | observability| 原生YAML (nginx:alpine) | 1    | ConfigMap
 jenkins                 | cicd         | Helm 5.9.65 (2.568.3)   | 1    | PVC 10Gi
 argocd                  | cicd         | Helm 10.9.6 (v3.5.3)    | 各1  | -
 registry (骨架)         | infra        | 原生YAML (registry:2)   | 0/1  | emptyDir
 app-sample (骨架)       | app-sample   | 原生YAML (nginx:alpine) | 0/1  | -
 gitlab(完整实例,未部署) | gitlab       | Helm gitlab/gitlab      | 多   | PVC(各依赖)

--------------------------------------------------------------------------------
 5. 端口与访问表 (Ports & Access)
--------------------------------------------------------------------------------
 组件           | Service (集群内)                          | Ingress Path  | 直连/port-forward
 ---------------+-------------------------------------------+---------------+----------------------------------
 ingress-nginx  | ingress-nginx-controller (NodePort)       | (全部path路由)| localhost:30080 / 30443
 首页 Dashboard | platform-dashboard:80        (observability) | /             | -
 Grafana        | kube-prometheus-stack-grafana:80     (obs.)  | /grafana      | pf 3000:80
 Prometheus     | kube-prometheus-stack-prometheus:9090(obs.) | /prometheus   | pf 9090:9090
 Alertmanager   | kube-prometheus-stack-alertmanager:9093(o.) | /alertmanager | pf 9093:9093
 Loki           | loki:3100                      (obs.)      | - (集群内)     | pf 3100:3100
 Alloy          | alloy-logs:12345               (obs.)      | -             | -
 Tempo          | tempo:3200 / OTLP 4317 / 4318 (obs.)       | - (集群内)     | pf 13200:3200
 Jenkins        | jenkins:8080                   (cicd)      | /jenkins      | pf 18080:8080(脚本)
 Argo CD        | argocd-server:80               (cicd)      | /argocd       | -
 Registry       | registry:5000                  (infra)     | /registry     | -
 Application    | app-sample:80                  (app-sample)| /application  | -
 GitLab         | gitlab-webservice:8181 (gitlab)| gitlab.gitlab.local (host) | pf 8080:8181

 注: node-exporter :9100, kube-state-metrics :8080, Prometheus Operator :443 (集群内采集/管理)

--------------------------------------------------------------------------------
 6. 连接依赖表 (Connection & Dependency Matrix)
--------------------------------------------------------------------------------
 # | From                          │ To                     │ 协议/端口        │ 用途
 --+-------------------------------+------------------------+------------------+---------------------------
 1 │ 浏览器                        │ ingress-nginx          │ HTTP 30080       │ 统一入口
 2 │ ingress-nginx                 │ platform-dashboard:80  │ HTTP path=/      │ 首页
 3 │ ingress-nginx                 │ Grafana:80             │ HTTP /grafana    │ 可视化UI
 4 │ ingress-nginx                 │ Prometheus:9090        │ HTTP /prometheus │ 指标UI
 5 │ ingress-nginx                 │ Alertmanager:9093      │ HTTP /alertmanager│ 告警UI
 6 │ ingress-nginx                 │ Jenkins:8080           │ HTTP /jenkins    │ CI UI
 7 │ ingress-nginx                 │ argocd-server:80       │ HTTP /argocd     │ GitOps UI
 8 │ node-exporter                 │ (被Prometheus scrape)  │ HTTP :9100       │ 节点指标
 9 │ kube-state-metrics            │ (被Prometheus scrape)  │ HTTP :8080       │ K8s对象指标
10 │ Prometheus                    │ Grafana                │ 数据源 :9090     │ 指标查询
11 │ Prometheus                    │ Alertmanager           │ alert push :9093 │ 告警分发
12 │ Alloy                         │ Kubernetes API         │ watch (RBAC)     │ 发现Pod/读日志
13 │ Alloy                         │ Loki                   │ Push :3100       │ 写入日志
14 │ Loki                          │ Grafana                │ 数据源 :3100     │ 日志查询
15 │ 应用(OTLP SDK)                │ Tempo                  │ gRPC 4317/HTTP4318│ 上报Trace
16 │ Tempo                         │ Grafana                │ 数据源 :3200     │ Trace查询
17 │ Jenkins Controller            │ Kubernetes API         │ K8s Plugin       │ 动态创建Agent Pod
18 │ Jenkins Agent Pod             │ Jenkins Controller     │ JNLP/HTTP :8080  │ Agent回连
19 │ Jenkins                       │ Registry               │ docker push :5000│ 推镜像(规划)
20 │ Argo CD                       │ Git 仓库               │ HTTPS            │ 拉取manifests
21 │ Argo CD                       │ Kubernetes API         │ apply            │ 同步应用
22 │ Argo CD                       │ Registry               │ 镜像拉取 :5000   │ (规划)
23 │ Grafana                       │ Prometheus/Loki/Tempo  │ 3个数据源        │ 统一查询
24 │ ingress-nginx                 │ gitlab-webservice:8181 │ HTTP host=gitlab.gitlab.local │ GitLab UI/API (host路由)
25 │ gitlab                        │ PostgreSQL/Redis/MinIO │ 集群内           │ 自带依赖(已关外部组件)
26 │ gitlab-runner (可选)          │ GitLab                 │ HTTP register   │ CI 执行器注册
27 │ GitLab CI (可选)              │ Registry               │ docker push :5000│ 推镜像到本地仓库

--------------------------------------------------------------------------------
 7. 命名空间视图 (Namespace Layout)
--------------------------------------------------------------------------------
 ingress          └─ ingress-nginx-controller (NodePort 30080/30443)
 observability    ├─ Ingress(observability): / /grafana /prometheus /alertmanager
                  ├─ kube-prometheus-stack (Prometheus/Grafana/Alertmanager/exporters)
                  ├─ loki, alloy-logs, tempo
                  └─ platform-dashboard (首页 ConfigMap + nginx)
 cicd             ├─ Ingress(cicd-ingress): /jenkins /argocd
                  ├─ jenkins (StatefulSet, PVC 10Gi)
                  └─ argocd (server/repo-server/controller/applicationSet/redis)
 infra            └─ registry (骨架, 待 apply)
 app-sample       └─ app-sample (骨架, 待 apply)
 gitlab           └─ (空, 未部署) 完整 GitLab CE 实例待装 (values 已备, 见 gitlab/)

--------------------------------------------------------------------------------
 8. 账号表 (Credentials — 仅本地Lab)
--------------------------------------------------------------------------------
 系统     | 用户名 | 密码
 ---------+--------+----------------
 Grafana  | admin  | admin123456
 Jenkins  | admin  | admin123456
 Argo CD  | admin  | 见 cicd/argocd/readme.md
 GitLab   | root  | kubectl -n gitlab get secret gitlab-initial-root-password

--------------------------------------------------------------------------------
 9. 关键备注 (Key Notes)
--------------------------------------------------------------------------------
 - Ingress 与 backend 必须同 namespace（故按 ns 拆成多个 Ingress 对象，均无 host）。
 - 子路径一致性: Grafana root_url+serve_from_sub_path / Prometheus & Alertmanager
   externalUrl+routePrefix 必须与 ingress path 一致，否则 404。
 - Jenkins 反代: 需 proxy-set-headers cicd/jenkins-proxy-headers（已在 cicd-ingress.yaml）。
 - Prometheus 当前无 PVC（临时存储），重启/挂起丢历史数据；Loki/Tempo/Jenkins 有 PVC。
 - 首页 5 分类: 监控(Grafana/Prometheus/Alertmanager) 日志(Loki/Alloy/Tempo)
   CICD(Jenkins/ArgoCD) APP(Application/Registry) 其它(Ingress网关)。
   改首页: kubectl apply -f cicd/dashboard/platform-dashboard.yaml + rollout restart。
 - 旧端口 30030/30031 (Grafana/Alertmanager直连NodePort) 已弃用，统一走 30080。
 - 后续规划: HTTPS + cert-manager + Let's Encrypt；Loki分布式+S3；Alloy DaemonSet。
 - GitLab (gitlab ns, 当前未部署): 完整自托管 GitLab CE，host 路由 gitlab.gitlab.local，
   需宿主机 /etc/hosts 加 127.0.0.1 gitlab.gitlab.local（及 registry/minio 子域）。
   已关 chart 自带 ingress/certmanager/prometheus/grafana，复用本平台组件；仅 HTTP。
   自带 PostgreSQL/Redis/MinIO（PVC）；GitLab Runner 默认关闭，按 gitlab/README 手动添加。

================================================================================
 (完) 相关文档: README.md / docs/operations.md / docs/ports-connections.md /
              docs/notes.md / docs/components/*.md
================================================================================
