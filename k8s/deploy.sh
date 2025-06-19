#!/bin/bash

set -e

echo "🚀 Starting deployment to Minikube..."

# Check if minikube is running
if ! minikube status | grep -q "Running"; then
    echo "Starting Minikube..."
    minikube start
fi

# Set docker environment to use minikube's docker daemon
eval $(minikube docker-env)

echo "📦 Building Docker images..."

# Build auth service
echo "Building auth-service..."
cd auth-service
docker build -f Dockerfile.k8s -t auth-service:latest .
cd ..

# Build persistence service
echo "Building persistence-service..."
cd persistence-service
docker build -f Dockerfile.k8s -t persistence-service:latest .
cd ..

# Build WebSocket service
echo "Building ws-service..."
cd ws-service
docker build -f Dockerfile.k8s -t ws-service:latest .
cd ..

echo "🔧 Applying Kubernetes manifests..."

# Create namespace
kubectl apply -f k8s/namespace.yaml

# Apply infrastructure components
kubectl apply -f k8s/postgres-configmap.yaml
kubectl apply -f k8s/postgres-pvc.yaml
kubectl apply -f k8s/postgres-deployment.yaml
kubectl apply -f k8s/postgres-service.yaml

kubectl apply -f k8s/kafka-configmap.yaml
kubectl apply -f k8s/zookeeper-deployment.yaml
kubectl apply -f k8s/zookeeper-service.yaml
kubectl apply -f k8s/kafka-deployment.yaml
kubectl apply -f k8s/kafka-service.yaml
# Apply Kafka topics (Strimzi)
kubectl apply -f k8s/messages-topic.yaml
kubectl apply -f k8s/persist-topic.yaml

# Wait for infrastructure to be ready
echo "⏳ Waiting for infrastructure to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/postgres -n messaging-app
kubectl wait --for=condition=ready --timeout=300s pod -l app=zookeeper -n messaging-app
kubectl wait --for=condition=ready --timeout=300s pod -l app=kafka -n messaging-app


# Apply service configurations
kubectl apply -f k8s/auth-service-configmap.yaml
kubectl apply -f k8s/persistence-service-configmap.yaml
kubectl apply -f k8s/ws-service-configmap.yaml

# Apply service deployments
kubectl apply -f k8s/auth-service-deployment.yaml
kubectl apply -f k8s/auth-service-service.yaml
kubectl apply -f k8s/persistence-service-deployment.yaml
kubectl apply -f k8s/ws-service-deployment.yaml
kubectl apply -f k8s/ws-service-service.yaml

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/auth-service -n messaging-app
kubectl wait --for=condition=available --timeout=300s deployment/persistence-service -n messaging-app
kubectl wait --for=condition=available --timeout=300s deployment/ws-service -n messaging-app

echo "✅ Deployment completed successfully!"

# Show service status
echo "📊 Service status:"
kubectl get pods -n messaging-app
kubectl get services -n messaging-app


# Port-forward auth-service to localhost:8080
echo "🔗 Port-forwarding auth-service to http://localhost:8080 ..."
kubectl port-forward -n messaging-app service/auth-service 8080:8080 > /dev/null 2>&1 &

# Port-forward ws-service to localhost:8081 (container port 8081)
echo "🔗 Port-forwarding ws-service to ws://localhost:8081/ws ..."
kubectl port-forward -n messaging-app service/ws-service 8081:8081 > /dev/null 2>&1 &

echo "🌟 Port-forwarding started. You can now access auth-service at http://localhost:8080 and ws-service at ws://localhost:8081/ws"

echo "🎉 Deployment complete! Your messaging application is now running on Minikube." 