# Application 运维指导 · Operations

## 1. 功能 Function
业务应用占位（当前为 `nginx:alpine` 示例），用于打通端到端链路：Jenkins 构建 → 推 Registry → Argo CD 同步 → 集群运行。真实上线时把镜像换成业务镜像即可。

## 2. 部署位置 Location
- Namespace：`app-sample`
- 镜像：`nginx:alpine`（替换为真实业务镜像）
- 文件：`application/`（namespace / deployment / service / ingress / install.sh / uninstall.sh）
- Service：`app-sample.app-sample.svc.cluster.local:80`（ClusterIP）
- Ingress：`/application` → `app-sample:80`

## 3. 安装 Start
```bash
cd application && chmod +x install.sh uninstall.sh
./install.sh
```

## 4. 更新 Update
```bash
kubectl apply -f deployment.yaml -f service.yaml -f ingress.yaml
# 改镜像后建议让 Argo CD 同步，或手动 apply
```

## 5. 停止 Stop
```bash
./uninstall.sh   # 删 ingress/service/deployment，保留 app-sample namespace
# 彻底：kubectl delete namespace app-sample
```

## 6. 挂起 / 恢复 Suspend / Resume
```bash
kubectl scale deployment app-sample -n app-sample --replicas=0   # 挂起
kubectl scale deployment app-sample -n app-sample --replicas=1   # 恢复
```

## 7. 健康检查 Health
```bash
kubectl get pods -n app-sample
kubectl get ingress -n app-sample
curl -I http://localhost:30080/application/
```

## 8. 访问 Access
- Web：`http://localhost:30080/application/`
- 集群内：`http://app-sample.app-sample.svc.cluster.local:80`

## 9. 常见问题 Troubleshooting
- **404 on `/application`**：确认 `app-sample` ns 的 Ingress 已 apply。
- **替换为业务镜像后起不来**：检查镜像可拉取、端口与 `containerPort`/`Service` targetPort 一致、 readiness 探针。

## 10. 配置要点 Notes
- 多业务建议按 `app-<name>` 命名 namespace，各自带 Ingress path（如 `/app-foo`），保持与首页卡片一致。
- 首页 `application` 卡片已联动：部署后即可点击。
- 真实 CD 由 Argo CD 管理；本目录是“骨架”，可直接作为 Argo CD 的 Git 源。
