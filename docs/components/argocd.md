# Argo CD 运维指导 · Operations

## 1. 功能 Function
GitOps 持续交付。监听 Git 仓库中的 manifests，与集群实际状态对比，自动（或手动）同步（apply）到 Kubernetes。本平台用于把应用部署到集群。

## 2. 部署位置 Location
- Namespace：`cicd`
- Release：`argocd`
- Chart：`argo/argo-cd`
- 配置：`cicd/argocd/values.yaml`
- Service：`argocd-server.cicd.svc.cluster.local:80`（ClusterIP）
- Ingress：`/argocd` → `argocd-server:80`
- 子组件：server / repo-server / controller / applicationSet / redis（dex、notifications 已禁用）

## 3. 安装 Start
```bash
cd cicd && ./install.sh            # 含 Argo CD + Jenkins + 首页
# 或单独：
helm upgrade --install argocd argo/argo-cd -n cicd -f argocd/values.yaml --wait --timeout 10m --atomic
```

## 4. 更新 Update
```bash
helm upgrade --install argocd argo/argo-cd -n cicd -f argocd/values.yaml --wait --timeout 10m --atomic
```

## 5. 停止 Stop
```bash
helm uninstall argocd -n cicd
```

## 6. 挂起 / 恢复 Suspend / Resume
Argo CD 自身挂起（停止同步）：
```bash
kubectl scale deployment argocd-server -n cicd --replicas=0
kubectl scale deployment argocd-server -n cicd --replicas=1
```
应用级挂起（不影响 Argo CD，仅暂停某 Application 同步）：
```bash
kubectl patch applications.argoproj.io <app> -n cicd --type merge -p '{"spec":{"suspend":true}}'   # 挂起
kubectl patch applications.argoproj.io <app> -n cicd --type merge -p '{"spec":{"suspend":false}}'  # 恢复
```

## 7. 健康检查 Health
```bash
kubectl get pods -n cicd -l app.kubernetes.io/instance=argocd
kubectl get svc  -n cicd | grep argocd
helm list -n cicd | grep argocd
```

## 8. 访问 Access
- Web：`http://localhost:30080/argocd/`（注意末尾 `/argocd/`）
- 初始账号：`admin`；密码见 `cicd/argocd/readme.md`
- CLI：`argocd login localhost:30080/argocd --username admin`

## 9. 常见问题 Troubleshooting
- **页面空白 / 静态资源 404**：`server.rootpath/basehref` 必须是 `/argocd`（已在 values 设 `server.insecure: true` + `rootpath /argocd` + `basehref /argocd/`），与 ingress path 一致。
- **无法同步 Git**：检查 repo-server 到 Git 的网络，以及 Application 中 repo URL / 凭证。
- **Out of sync 不自动修复**：确认 Application `syncPolicy` 是否开启 auto-sync。

## 10. 配置要点 Notes
- 本地关闭了 Dex 与 notifications（简化）。
- 多业务可按 Application 粒度挂起；Argo CD 本身挂起会停止所有同步。
