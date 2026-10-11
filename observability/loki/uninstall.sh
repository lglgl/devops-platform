#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="observability"
RELEASE="loki"

helm uninstall "${RELEASE}" -n "${NAMESPACE}" || true

echo "Loki Helm release removed."
echo "PVCs are intentionally retained."
echo "If you also want to remove Loki data:"
echo "kubectl delete pvc -n ${NAMESPACE} -l app.kubernetes.io/name=loki"
