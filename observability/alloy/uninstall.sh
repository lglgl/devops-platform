#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="observability"
RELEASE="alloy-logs"

helm uninstall "${RELEASE}" -n "${NAMESPACE}" || true
kubectl delete clusterrolebinding alloy-logs --ignore-not-found
kubectl delete clusterrole alloy-logs --ignore-not-found
kubectl delete serviceaccount alloy-logs -n "${NAMESPACE}" --ignore-not-found

echo "Alloy logs collector removed."
