# PowerShell cleanup script for Minikube

Write-Host "🧹 Cleaning up messaging application from Minikube..." -ForegroundColor Yellow

# Delete all resources in the messaging-app namespace
kubectl delete namespace messaging-app --ignore-not-found=true

# Set docker environment to use minikube's docker daemon
$env:DOCKER_TLS_VERIFY = "1"
$env:DOCKER_HOST = "tcp://$(minikube ip):2376"
$env:DOCKER_CERT_PATH = "$env:USERPROFILE\.minikube\certs"

# Remove Docker images
docker rmi auth-service:latest --force 2>$null
docker rmi persistence-service:latest --force 2>$null
docker rmi ws-service:latest --force 2>$null

Write-Host "✅ Cleanup completed!" -ForegroundColor Green 