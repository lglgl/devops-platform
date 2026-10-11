# ============================================================
# 1. 检查当前 CICD Jenkins
# ============================================================

echo "========== CICD Jenkins =========="

kubectl get pods -n cicd \
  -l app.kubernetes.io/instance=jenkins \
  -o wide

echo

kubectl get svc -n cicd \
  | grep -E 'jenkins|NAME'

echo

helm list -n cicd \
  | grep -E 'jenkins|NAME'


# ============================================================
# 2. 删除旧 Jenkins Namespace
#
# 旧 Jenkins 位于：
#
#   namespace: jenkins
#
# 新 Jenkins 位于：
#
#   namespace: cicd
#
# 两者互不影响。
# ============================================================

echo
echo "========== 删除旧 Jenkins =========="

if kubectl get namespace jenkins >/dev/null 2>&1; then

  echo "发现旧 Jenkins namespace，开始删除..."

  kubectl delete namespace jenkins

  echo "旧 Jenkins namespace 删除命令已执行"

else

  echo "旧 Jenkins namespace 不存在"

fi


# ============================================================
# 3. 检查旧 Jenkins 是否已经消失
# ============================================================

echo
echo "========== 检查旧 Jenkins =========="

if kubectl get namespace jenkins >/dev/null 2>&1; then

  echo "WARNING: jenkins namespace 仍然存在"
  kubectl get all -n jenkins 2>/dev/null || true

else

  echo "旧 Jenkins namespace 已删除"

fi


# ============================================================
# 4. 检查当前 CICD Ingress
# ============================================================

echo
echo "========== CICD Ingress =========="

kubectl get ingress -n cicd

echo

kubectl get ingress cicd-ingress \
  -n cicd \
  -o jsonpath='{range .spec.rules[*].http.paths[*]}{.path} -> {.backend.service.name}:{.backend.service.port.number}{"\n"}{end}'


# ============================================================
# 5. 检查 Jenkins Service
# ============================================================

echo
echo "========== Jenkins Service =========="

kubectl get svc jenkins -n cicd -o wide


# ============================================================
# 6. 检查 Jenkins URL
# ============================================================

echo
echo "========== Jenkins URL =========="

echo "http://localhost:30080/jenkins/"


# ============================================================
# 7. 测试 Jenkins HTTP
# ============================================================

echo
echo "========== Jenkins HTTP Test =========="

curl -I \
  --max-time 10 \
  http://localhost:30080/jenkins/ \
  || true


# ============================================================
# 8. Jenkins Reverse Proxy 专项检测
#
# Jenkins 官方 Reverse Proxy Setup Monitor。
# ============================================================

echo
echo "========== Jenkins Reverse Proxy Test =========="

curl -iL \
  --max-time 15 \
  -e http://localhost:30080/jenkins/manage \
  http://localhost:30080/jenkins/administrativeMonitor/hudson.diagnosis.ReverseProxySetupMonitor/test \
  || true


# ============================================================
# 9. 检查 Jenkins Controller 启动参数
# ============================================================

echo
echo "========== Jenkins Container Args =========="

JENKINS_POD=$(kubectl get pod \
  -n cicd \
  -l app.kubernetes.io/instance=jenkins \
  -o jsonpath='{.items[0].metadata.name}')

echo "Pod: ${JENKINS_POD}"

kubectl get pod "${JENKINS_POD}" \
  -n cicd \
  -o jsonpath='{range .spec.containers[0].args[*]}{.}{"\n"}{end}'


# ============================================================
# 10. 检查 Jenkins 环境变量
# ============================================================

echo
echo "========== Jenkins Environment =========="

kubectl get pod "${JENKINS_POD}" \
  -n cicd \
  -o jsonpath='{range .spec.containers[0].env[*]}{.name}={.value}{"\n"}{end}' \
  | grep -E 'JENKINS|JAVA' \
  || true


# ============================================================
# 11. 最终 CICD 状态
# ============================================================

echo
echo "============================================================"
echo "CICD FINAL STATUS"
echo "============================================================"

echo
echo "[Pods]"
kubectl get pods -n cicd -o wide

echo
echo "[Services]"
kubectl get svc -n cicd

echo
echo "[Ingress]"
kubectl get ingress -n cicd

echo
echo "[Helm]"
helm list -n cicd

echo
echo "============================================================"
echo "完成"
echo "============================================================"