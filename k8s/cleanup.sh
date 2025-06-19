#!/bin/bash

echo "🧹 Cleaning up messaging application from Minikube..."

# Delete all resources in the messaging-app namespace
kubectl delete namespace messaging-app --ignore-not-found=true

# Remove Docker images
eval $(minikube docker-env)
docker rmi auth-service:latest --force 2>/dev/null || true
docker rmi persistence-service:latest --force 2>/dev/null || true
docker rmi ws-service:latest --force 2>/dev/null || true

echo "✅ Cleanup completed!"