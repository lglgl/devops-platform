# SRE CICD Kubernetes 安装包

适用环境：

- Docker Desktop Kubernetes
- namespace: cicd
- StorageClass: hostpath
- ingress-nginx IngressClass: nginx
- NGINX HTTP NodePort: 30080

访问地址：

- Jenkins: http://localhost:30080/jenkins/
- Argo CD: http://localhost:30080/argocd/
- Grafana: http://localhost:30080/grafana/
- Prometheus: http://localhost:30080/prometheus/
- Alertmanager: http://localhost:30080/alertmanager/

Jenkins：

- 用户名：admin
- 密码：admin123456

说明：
Jenkins Agent 不部署为长期运行的固定 Pod。Jenkins Kubernetes Plugin 会根据 Pipeline 动态创建临时 Agent Pod，任务完成后自动删除。




============================================================
CICD 安装完成
=============

SRE Platform:
  http://localhost:30080/

Jenkins:
  http://localhost:30080/jenkins/
  Username: admin
  Password: admin123456

Argo CD:
  http://localhost:30080/argocd/

检查命令:
  kubectl get pods -n cicd
  kubectl get svc -n cicd
  kubectl get ingress -n cicd
  helm list -n cicd

============================================================
下一步：验证 Jenkins Kubernetes Dynamic Agent
=============================================
