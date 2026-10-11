# Jenkins 运维指导 · Operations

## 1. 功能 Function
CI 引擎。运行 Pipeline（构建/测试），通过 Kubernetes Plugin 在 Pipeline 期间**动态创建临时 Agent Pod** 执行任务，结束后自动删除。`numExecutors=0`，Controller 本身不跑任务。

## 2. 部署位置 Location
- Namespace：`cicd`
- Release：`jenkins`
- Chart：`jenkins/jenkins`
- 配置：`cicd/jenkins/values.yaml`
- Service：`jenkins.cicd.svc.cluster.local:8080`（ClusterIP）
- Ingress：`/jenkins` → `jenkins:8080`
- 存储：PVC 10Gi（hostpath）

## 3. 安装 Start
```bash
cd cicd && ./install.sh            # 含 Jenkins + Argo CD + 首页
# 或单独安装 Jenkins：
helm upgrade --install jenkins jenkins/jenkins -n cicd -f jenkins/values.yaml --wait --timeout 10m --atomic
```
首次启动需下载插件，给 10 分钟。

## 4. 更新 Update
```bash
helm upgrade --install jenkins jenkins/jenkins -n cicd -f jenkins/values.yaml --wait --timeout 10m --atomic
```
改插件/资源/JCasC 后重跑。`--atomic` 失败自动回滚。

## 5. 停止 Stop
```bash
helm uninstall jenkins -n cicd     # PVC 默认保留
# 彻底清理：kubectl delete namespace cicd
```

## 6. 挂起 / 恢复 Suspend / Resume
```bash
kubectl scale deployment jenkins -n cicd --replicas=0   # 挂起
kubectl scale deployment jenkins -n cicd --replicas=1   # 恢复
```
> Agent Pod 是临时的，挂起 Controller 后即不再派发任务。

## 7. 健康检查 Health
```bash
kubectl get pods -n cicd -l app.kubernetes.io/instance=jenkins
kubectl get svc  -n cicd | grep jenkins
helm list -n cicd | grep jenkins
```

## 8. 访问 Access
- Web：`http://localhost:30080/jenkins/`
- 账号：`admin / admin123456`
- 直连转发：`cicd/jenkins/jenkins-port-forward.sh {start|stop|restart|status|logs}`（本地 18080）
- 反向代理专项检测：见 `cicd/x.sh`

## 9. 常见问题 Troubleshooting
- **ReverseProxySetupMonitor 告警**：必须设 `nginx.ingress.kubernetes.io/proxy-set-headers: cicd/jenkins-proxy-headers`（已在 `cicd/ingress/cicd-ingress.yaml`），且 `jenkinsUrl` 指向入口 `http://localhost:30080/jenkins/`，否则 Jenkins 误判外部地址。
- **Agent 起不来**：检查 `cicd` ns 的 Jenkins ServiceAccount/RBAC，以及 agent 镜像 `jenkins/inbound-agent` 可拉取。
- **大文件上传失败**：`cicd-ingress.yaml` 已设 `proxy-body-size: 100m` 与长超时，必要时调大。

## 10. 配置要点 Notes
- 动态 Agent：`containerCap: 3`、`podRetention: Never`、`namespace: cicd`、`jenkinsUrl: http://jenkins.cicd.svc.cluster.local:8080`。
- 配置即代码（JCasC）已启用；账号明文仅限本地 Lab。
