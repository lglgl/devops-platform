# ingress-nginx 运维指导 · Operations

## 1. 功能 Function
Kubernetes Ingress Controller（NGINX）。平台统一 HTTP/HTTPS 网关，按 URL path 把请求转发到各后端 Service。所有 Web UI 经它暴露，无需 `/etc/hosts`。

## 2. 部署位置 Location
- Namespace：`ingress`
- Release：`ingress-nginx`
- Chart：`ingress-nginx/ingress-nginx`
- 关键配置：`ingress-nginx/values.yaml`（NodePort 30080/30443，replicaCount 1，IngressClass `nginx` 默认，metrics 开启，admissionWebhooks 开启）

## 3. 安装 Start
```bash
cd ingress-nginx && chmod +x install.sh uninstall.sh
./install.sh
```
脚本：建 `ingress` ns → 加 repo → `helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx -n ingress -f values.yaml --wait`。

## 4. 更新 Update
```bash
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx -n ingress -f values.yaml --wait
```
改 NodePort / 资源 / IngressClass 后重跑即可。

## 5. 停止 Stop
```bash
./uninstall.sh
# = helm uninstall ingress-nginx -n ingress + kubectl delete namespace ingress
```
> ⚠️ 停止后**所有**经 30080/30443 的访问全部中断。

## 6. 挂起 / 恢复 Suspend / Resume
```bash
kubectl scale deployment ingress-nginx-controller -n ingress --replicas=0   # 挂起
kubectl scale deployment ingress-nginx-controller -n ingress --replicas=1   # 恢复
```

## 7. 健康检查 Health
```bash
kubectl get pods -n ingress
kubectl get svc -n ingress
kubectl get ingressclass
```

## 8. 访问 Access
- HTTP：`http://localhost:30080`
- HTTPS：`https://localhost:30443`（当前未配证书，主要用 HTTP）
- 日志：`kubectl logs -n ingress deployment/ingress-nginx-controller`

## 9. 常见问题 Troubleshooting
- **404 on `/grafana` 等**：检查对应 Ingress 对象是否存在且 backend service 在同 namespace。
- **规则不生效**：确认 Ingress 设 `ingressClassName: nginx`，且 Controller 的 `watchIngressWithoutClass` 为 false（本配置）。
- **path 冲突**：无 host 时按 path 长度优先，`/jenkins` 优先于首页 `/`。

## 10. 配置要点 Notes
- 多个 Ingress 对象跨 namespace（observability/cicd/infra/app-sample），但 Controller 在 `ingress`；K8s 要求 Ingress 的 backend Service 与 Ingress 同 namespace。
- 未来接入 cert-manager + Let's Encrypt 做正式 TLS。
