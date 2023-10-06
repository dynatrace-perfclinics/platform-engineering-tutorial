#!/bin/bash

# Download kubectl
curl -LO https://dl.k8s.io/release/v1.27.4/bin/linux/amd64/kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Download helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# create local registry
echo "-- Create docker network"
docker network create k3d
echo "-- Create container registry on port 5500"
k3d registry create registry.localhost --port 5500
docker network connect k3d k3d-registry.localhost

# Create cluster
echo "-- Create kubernetes cluster"
k3d cluster create --config=.devcontainer/cluster.yml

echo "-- Deploy ArgoCD"
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "-- Configuring ArgoCD for no TLS"
kubectl -n argocd apply -f .devcontainer/argocd-no-tls.yml

echo "-- Restarting ArgoCD server to pick up TLS changes"
kubectl -n argocd scale deploy/argocd-server --replicas=0
kubectl -n argocd scale deploy/argocd-server --replicas=1

kubectl -n argocd rollout status deploy/argocd-server --timeout=300s

echo "-- Download ArgoCD CLI"
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
echo "ArgoCD CLI downloaded"
