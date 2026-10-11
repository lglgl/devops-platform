# NGINX Ingress 本地平台入口

## 一、目标

当前不修改 MacBook 的 `/etc/hosts`。

统一使用：

```text
http://localhost:30080
```

进入 Kubernetes SRE 平台首页。

首页提供：

```text
Grafana
Prometheus
Alertmanager
```

点击后继续由 NGINX Ingress 根据 URL Path 转发。

---

## 二、访问结构

```text
浏览器
  |
  | http://localhost:30080
  v
NGINX Ingress
  |
  v
Platform Dashboard
  |
  +---- /grafana
  |        |
  |        v
  |     Grafana
  |
  +---- /prometheus
  |        |
  |        v
  |     Prometheus
  |
  +---- /alertmanager
           |
           v
       Alertmanager
```

不需要：

```text
/etc/hosts
```

不需要：

```text
grafana.example.local
prometheus.example.local
```

---

## 三、文件

```text
ingress-nginx/
|
+-- values.yaml
+-- dashboard.yaml
+-- observability-values-patch.yaml
+-- apply-dashboard.sh
+-- README.md
```

---

## 四、先修改 kube-prometheus-stack

将：

```text
observability-values-patch.yaml
```

中的配置合并到：

```text
../observability/kube-prometheus-stack/values.yaml
```

重点是：

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

然后执行 Helm upgrade。

---

## 五、Helm Upgrade

进入 kube-prometheus-stack：

```bash
cd ../observability/kube-prometheus-stack
```

执行：

```bash
helm upgrade --install kube-prometheus-stack   prometheus-community/kube-prometheus-stack   --namespace observability   --values values.yaml   --wait   --timeout 10m
```

---

## 六、部署首页和 Ingress

回到 ingress 目录：

```bash
cd ../../ingress-nginx
```

执行：

```bash
chmod +x apply-dashboard.sh
./apply-dashboard.sh
```

---

## 七、访问

浏览器打开：

```text
http://localhost:30080
```

首页：

```text
Kubernetes SRE Platform

+----------------+
|    Grafana     |
+----------------+

+----------------+
|   Prometheus   |
+----------------+

+----------------+
|  Alertmanager  |
+----------------+
```

点击即可访问。

---

## 八、直接访问

也可以直接访问：

```text
http://localhost:30080/grafana/
```

```text
http://localhost:30080/prometheus/
```

```text
http://localhost:30080/alertmanager/
```

---

## 九、查看 Ingress

```bash
kubectl get ingress -n observability
```

查看详细配置：

```bash
kubectl describe ingress observability   -n observability
```

---

## 十、查看 NGINX Controller

```bash
kubectl get pods -n ingress
```

查看日志：

```bash
kubectl logs   -n ingress   deployment/ingress-nginx-controller
```

---

## 十一、重要说明

NGINX Ingress Controller 在：

```text
namespace: ingress
```

但是这里的 Ingress 对象在：

```text
namespace: observability
```

原因是 Kubernetes Ingress 的 backend Service 必须与 Ingress 对象位于同一个 Namespace。

因此：

```text
ingress
└── NGINX Ingress Controller

observability
└── Ingress
    ├── platform-dashboard
    ├── Grafana
    ├── Prometheus
    └── Alertmanager
```

这是正常的 Kubernetes 设计。

---

## 十二、平台首页（当前）

统一入口 `http://localhost:30080/`，首页分 5 类（见 `cicd/dashboard/platform-dashboard.yaml`）：

```text
+--------------------------+
| SRE Platform             |
+--------------------------+
| 监控 Monitoring           |
|   Grafana / Prometheus /  |
|   Alertmanager            |
| 日志 Logs & Trace         |
|   Loki / Alloy / Tempo    |
| CICD · GitOps             |
|   Jenkins / Argo CD       |
| APP · 应用                |
|   Application / Registry  |
| 其它 Other                |
|   Ingress 网关            |
+--------------------------+
```

各组件 Ingress Path（全部无 host，按 path 长度优先匹配）：

```text
/            -> platform-dashboard  (首页,    observability)
/grafana     -> Grafana             (        observability)
/prometheus  -> Prometheus          (        observability)
/alertmanager-> Alertmanager        (        observability)
/jenkins     -> Jenkins             (        cicd)
/argocd      -> Argo CD             (        cicd)
/registry    -> Registry            (infra,  部署见 registry/)
/application -> Application         (app-sample, 部署见 application/)
```

> 说明：Ingress 对象按 backend 所在 namespace 拆分——首页 / Grafana 等在 `observability`，
> Jenkins / Argo CD 在 `cicd`，Registry 在 `infra`，Application 在 `app-sample`。
> K8s 要求 **Ingress 的 backend Service 与 Ingress 同 namespace**。

---

## 十三、后续扩展

将 HTTP 切换到 HTTPS，并使用：

```text
cert-manager
+
Let's Encrypt
```

完成正式的 TLS 入口层。后续可补充更多业务应用 namespace（`app-*`）。
