# PowerShell deployment script for Minikube

Write-Host "🚀 Starting deployment to Minikube..." -ForegroundColor Green

# Check if minikube is running
$minikubeStatus = minikube status
if ($minikubeStatus -notmatch "Running") {
    Write-Host "Starting Minikube..." -ForegroundColor Yellow
    minikube start
}

# Set docker environment to use minikube's docker daemon
$env:DOCKER_TLS_VERIFY = "1"
$env:DOCKER_HOST = "tcp://$(minikube ip):2376"
$env:DOCKER_CERT_PATH = "$env:USERPROFILE\.minikube\certs"

Write-Host "📦 Building Docker images..." -ForegroundColor Green

# Build auth service
Write-Host "Building auth-service..." -ForegroundColor Yellow
Set-Location ..\auth-service
docker build -f Dockerfile.k8s -t auth-service:latest .
Set-Location ..\k8s

# Build persistence service
Write-Host "Building persistence-service..." -ForegroundColor Yellow
Set-Location ..\persistence-service
docker build -f Dockerfile.k8s -t persistence-service:latest .
Set-Location ..\k8s

# Build WebSocket service
Write-Host "Building ws-service..." -ForegroundColor Yellow
Set-Location ..\ws-service
docker build -f Dockerfile.k8s -t ws-service:latest .
Set-Location ..\k8s

Write-Host "🔧 Applying Kubernetes manifests..." -ForegroundColor Green

# Create namespace
kubectl apply -f namespace.yaml

# Apply infrastructure components
kubectl apply -f postgres-configmap.yaml
kubectl apply -f postgres-pvc.yaml
kubectl apply -f postgres-deployment.yaml
kubectl apply -f postgres-service.yaml

kubectl apply -f kafka-configmap.yaml
kubectl apply -f zookeeper-deployment.yaml
kubectl apply -f zookeeper-service.yaml
kubectl apply -f kafka-deployment.yaml
kubectl apply -f kafka-service.yaml

# Wait for infrastructure to be ready
Write-Host "⏳ Waiting for infrastructure to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=available --timeout=300s deployment/postgres -n messaging-app
kubectl wait --for=condition=ready --timeout=300s pod -l app=zookeeper -n messaging-app
kubectl wait --for=condition=ready --timeout=300s pod -l app=kafka -n messaging-app

# Apply Kafka topics (Strimzi)
kubectl apply -f messages-topic.yaml
kubectl apply -f persist-topic.yaml

# Apply service configurations
kubectl apply -f auth-service-configmap.yaml
kubectl apply -f persistence-service-configmap.yaml
kubectl apply -f ws-service-configmap.yaml

# Apply service deployments
kubectl apply -f auth-service-deployment.yaml
kubectl apply -f auth-service-service.yaml
kubectl apply -f persistence-service-deployment.yaml
kubectl apply -f ws-service-deployment.yaml
kubectl apply -f ws-service-service.yaml

# Wait for services to be ready
Write-Host "⏳ Waiting for services to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=available --timeout=300s deployment/auth-service -n messaging-app
kubectl wait --for=condition=available --timeout=300s deployment/persistence-service -n messaging-app
kubectl wait --for=condition=available --timeout=300s deployment/ws-service -n messaging-app

Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green

# Show service status
Write-Host "📊 Service status:" -ForegroundColor Cyan
kubectl get pods -n messaging-app
kubectl get services -n messaging-app

# Port-forward auth-service to localhost:8080
Write-Host "🔗 Port-forwarding auth-service to http://localhost:8080 ..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList 'kubectl port-forward -n messaging-app service/auth-service 8080:8080' -WindowStyle Hidden

# Port-forward ws-service to localhost:8081 (container port 8081)
Write-Host "🔗 Port-forwarding ws-service to ws://localhost:8081/ws ..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList 'kubectl port-forward -n messaging-app service/ws-service 8081:8081' -WindowStyle Hidden

Write-Host "🌟 Port-forwarding started. You can now access auth-service at http://localhost:8080 and ws-service at http://localhost:8081" -ForegroundColor Green

Write-Host "🎉 Deployment complete! Your messaging application is now running on Minikube." -ForegroundColor Green 