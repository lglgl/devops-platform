# Alloy 运维指导 · Operations

## 1. 功能 Function
Grafana Alloy —— 可观测性采集 Agent。在本平台负责**日志采集**：watch Kubernetes API 获取各 Pod 的 stdout/stderr，处理后通过 Loki Push API 写入 Loki。

## 2. 部署位置 Location
- Namespace：`observability`
- Release：`alloy-logs`
- Chart：`grafana/alloy`
- 配置：`observability/alloy/values.yaml`
- 数据出口：`http://loki.observability.svc.cluster.local:3100/loki/api/v1/push`
- RBAC：由 Helm 管理（ServiceAccount / ClusterRole / ClusterRoleBinding）

## 3. 安装 Start
```bash
cd observability/alloy && chmod +x install.sh uninstall.sh
./install.sh
```
脚本：检查 helm/kubectl → 建 ns → 加 `grafana` repo → `helm upgrade --install alloy-logs grafana/alloy -n observability -f values.yaml` → `rollout status`。

## 4. 更新 Update
```bash
helm upgrade --install alloy-logs grafana/alloy -n observability -f values.yaml
```
改采集规则（values 中的 Alloy 配置）后重跑。

## 5. 停止 Stop
```bash
helm uninstall alloy-logs -n observability
```

## 6. 挂起 / 恢复 Suspend / Resume
```bash
kubectl scale deployment alloy-logs -n observability --replicas=0   # 挂起（停止采日志）
kubectl scale deployment alloy-logs -n observability --replicas=1   # 恢复
```

## 7. 健康检查 Health
```bash
kubectl get pods -n observability -l app.kubernetes.io/name=alloy-logs
kubectl get serviceaccount -n observability | grep alloy
kubectl get clusterrole,clusterrolebinding | grep alloy
```

## 8. 访问 Access
- Alloy 无独立 UI；采集状态通过日志与 Grafana(Loki) 间接验证。
- 配置查看：`kubectl get configmap -n observability alloy-logs -o yaml`

## 9. 常见问题 Troubleshooting
```bash
# 看采集日志
kubectl logs -n observability -l app.kubernetes.io/name=alloy-logs --tail=200
# 看配置
kubectl get configmap -n observability alloy-logs -o yaml
# RBAC 排查
kubectl get clusterrole alloy-logs; kubectl get clusterrolebinding alloy-logs
```
- **收不到某 namespace 日志**：确认 Alloy 有对应 RBAC（ClusterRole 已含 pods/log 等）；或该 ns 是否有 Pod 产出 stdout。

## 10. 配置要点 Notes
- RBAC 完全由 Helm 管理，**不要再手跑 rbac.yaml**（旧方案已弃用）。
- 当前单副本 Deployment；后续可升级为 **DaemonSet**（每节点一个）以贴近生产。
- 除日志外，Alloy 也能采 Metrics/Traces，本平台仅用于日志。
