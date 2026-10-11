#!/bin/bash

set -e

NAMESPACE="ingress"
RELEASE_NAME="ingress-nginx"

echo "Uninstalling NGINX Ingress Controller..."

helm uninstall "$RELEASE_NAME" \
  --namespace "$NAMESPACE" \
  || true

echo "Removing namespace..."

kubectl delete namespace "$NAMESPACE" \
  --ignore-not-found=true

echo "NGINX Ingress removed."