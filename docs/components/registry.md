# Registry 运维指导 · Operations

## 1. 功能 Function
容器镜像仓库（基于官方 `registry:2`）。承接 CI（Jenkins）构建出的镜像，供 GitOps（Argo CD）或集群拉取部署。本地 Lab 用，无 TLS / 无认证。

## 2. 部署位置 Location
- Namespace：`infra`
- 镜像：`registry:2`
- 文件：`registry/`（namespace / deployment / service / ingress / install.sh / uninstall.sh）
- Service：`registry.infrastructure.svc.cluster.local:5000`（ClusterIP）
- Ingress：`/registry` → `registry:5000`
- 存储：`emptyDir`（重启丢镜像）— 生产应换 PVC / 对象存储

## 3. 安装 Start
```bash
cd registry && chmod +x install.sh uninstall.sh
./install.sh
```
脚本 apply：namespace → deployment → service → ingress，并等待 Ready。

## 4. 更新 Update
```bash
kubectl apply -f deployment.yaml -f service.yaml -f ingress.yaml
```
换镜像版本或调资源后重跑。

## 5. 停止 Stop
```bash
./uninstall.sh   # 删 ingress/service/deployment，保留 infra namespace
# 彻底：kubectl delete namespace infra
```

## 6. 挂起 / 恢复 Suspend / Resume
```bash
kubectl scale deployment registry -n infra --replicas=0   # 挂起
kubectl scale deployment registry -n infra --replicas=1   # 恢复
```

## 7. 健康检查 Health
```bash
kubectl get pods -n infra
kubectl get ingress -n infra
curl -I http://localhost:30080/registry/v2/   # 期望 200
```

## 8. 访问 Access
- Web/API：`http://localhost:30080/registry/`
- 推送示例：
```bash
docker tag myapp:latest localhost:30080/registry/myapp:latest
docker push localhost:30080/registry/myapp:latest
```

## 9. 常见问题 Troubleshooting
- **docker push 被拒（https/insecure）**：Docker Desktop 需把 `localhost:30080` 加入 **insecure registries**（或走 HTTPS）。
- **404 on `/registry`**：确认 `infra` ns 的 Ingress 已 apply，且 Controller 正常。

## 10. 配置要点 Notes
- Ingress 与 Service 同在 `infra`，满足 K8s 同 namespace 要求。
- 生产建议升级为 **Harbor**（含认证、镜像扫描、副本），并加 TLS。
- 首页 `registry` 卡片已联动：部署后即可点击。
