#!/bin/bash

set -e

NAMESPACE="ingress"
RELEASE_NAME="ingress-nginx"
CHART_REPO="https://kubernetes.github.io/ingress-nginx"

echo "======================================"
echo " Installing NGINX Ingress Controller"
echo "======================================"

echo
echo "[1/5] Checking Kubernetes..."

kubectl cluster-info

echo
echo "[2/5] Creating namespace..."

kubectl apply -f namespace.yaml

echo
echo "[3/5] Adding Helm repository..."

helm repo add ingress-nginx "$CHART_REPO" 2>/dev/null || true
helm repo update

echo
echo "[4/5] Installing NGINX Ingress Controller..."

helm upgrade --install "$RELEASE_NAME" \
  ingress-nginx/ingress-nginx \
  --namespace "$NAMESPACE" \
  --values values.yaml \
  --wait

echo
echo "[5/5] Checking deployment..."

kubectl get pods \
  -n "$NAMESPACE" \
  -o wide

echo
echo "======================================"
echo " NGINX Ingress installed"
echo "======================================"

echo
echo "Service:"
kubectl get svc -n "$NAMESPACE"

echo
echo "IngressClass:"
kubectl get ingressclass

echo
echo "HTTP:"
echo "http://localhost:30080"

echo
echo "HTTPS:"
echo "https://localhost:30443"