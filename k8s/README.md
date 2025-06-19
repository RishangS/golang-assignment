# Kubernetes Deployment for Messaging Application

This directory contains Kubernetes manifests to deploy the messaging application on Minikube.

## Architecture

The application consists of the following components:

- **PostgreSQL**: Database for user authentication and message persistence
- **Zookeeper**: Required for Kafka cluster management
- **Kafka**: Message broker for real-time messaging and persistence
- **Auth Service**: gRPC service for user authentication and JWT token management
- **Persistence Service**: Kafka consumer that persists messages to PostgreSQL
- **WebSocket Service**: WebSocket server for real-time messaging

## Prerequisites

1. **Minikube**: A local Kubernetes cluster
   ```bash
   # Install Minikube
   curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
   sudo install minikube-linux-amd64 /usr/local/bin/minikube
   
   # Start Minikube
   minikube start
   ```

2. **kubectl**: Kubernetes command-line tool
   ```bash
   # Install kubectl
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
   ```

3. **Docker**: Container runtime
   ```bash
   # Install Docker
   sudo apt-get update
   sudo apt-get install docker.io
   sudo systemctl start docker
   sudo systemctl enable docker
   ```

## Deployment

### Quick Start

1. **Deploy the application**:
   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```

2. **Access the WebSocket service**:
   ```bash
   minikube service ws-service -n messaging-app --url
   ```

3. **Monitor the deployment**:
   ```bash
   kubectl get pods -n messaging-app
   kubectl get services -n messaging-app
   ```

### Manual Deployment

If you prefer to deploy manually:

1. **Create namespace**:
   ```bash
   kubectl apply -f namespace.yaml
   ```

2. **Deploy infrastructure**:
   ```bash
   kubectl apply -f postgres-configmap.yaml
   kubectl apply -f postgres-pvc.yaml
   kubectl apply -f postgres-deployment.yaml
   kubectl apply -f postgres-service.yaml
   
   kubectl apply -f kafka-configmap.yaml
   kubectl apply -f zookeeper-deployment.yaml
   kubectl apply -f zookeeper-service.yaml
   kubectl apply -f kafka-deployment.yaml
   kubectl apply -f kafka-service.yaml
   ```

3. **Deploy services**:
   ```bash
   kubectl apply -f auth-service-configmap.yaml
   kubectl apply -f auth-service-deployment.yaml
   kubectl apply -f auth-service-service.yaml
   
   kubectl apply -f persistence-service-configmap.yaml
   kubectl apply -f persistence-service-deployment.yaml
   
   kubectl apply -f ws-service-configmap.yaml
   kubectl apply -f ws-service-deployment.yaml
   kubectl apply -f ws-service-service.yaml
   ```

## Building Docker Images

Before deploying, you need to build the Docker images:

```bash
# Set Docker environment to use Minikube's Docker daemon
eval $(minikube docker-env)

# Build auth service
cd ../auth-service
docker build -f Dockerfile.k8s -t auth-service:latest .

# Build persistence service
cd ../persistence-service
docker build -f Dockerfile.k8s -t persistence-service:latest .

# Build WebSocket service
cd ../ws-service
docker build -f Dockerfile.k8s -t ws-service:latest .
```

## Configuration

### Environment Variables

The services are configured using ConfigMaps:

- **Auth Service**: Database connection and Kafka configuration
- **Persistence Service**: Database connection and Kafka consumer configuration
- **WebSocket Service**: Auth service address and Kafka configuration

### Service Discovery

Services communicate using Kubernetes service names:
- Auth Service: `auth-service:50051`
- Kafka: `kafka:9092`
- PostgreSQL: `postgres:5432`

## Monitoring and Debugging

### View Logs

```bash
# View auth service logs
kubectl logs -f deployment/auth-service -n messaging-app

# View persistence service logs
kubectl logs -f deployment/persistence-service -n messaging-app

# View WebSocket service logs
kubectl logs -f deployment/ws-service -n messaging-app

# View Kafka logs
kubectl logs -f deployment/kafka -n messaging-app

# View PostgreSQL logs
kubectl logs -f deployment/postgres -n messaging-app
```

### Port Forwarding

For local development and testing:

```bash
# Forward auth service HTTP port
kubectl port-forward service/auth-service 8080:8080 -n messaging-app

# Forward WebSocket service port
kubectl port-forward service/ws-service 8081:8081 -n messaging-app

# Forward PostgreSQL port
kubectl port-forward service/postgres 5432:5432 -n messaging-app
```

### Health Checks

All services expose health check endpoints:
- Auth Service: `http://localhost:8080/health`
- WebSocket Service: `http://localhost:8081/health`

## Scaling

To scale services:

```bash
# Scale auth service to 3 replicas
kubectl scale deployment auth-service --replicas=3 -n messaging-app

# Scale WebSocket service to 2 replicas
kubectl scale deployment ws-service --replicas=2 -n messaging-app
```

## Cleanup

To remove the entire deployment:

```bash
chmod +x cleanup.sh
./cleanup.sh
```

Or manually:

```bash
kubectl delete namespace messaging-app
```

## Troubleshooting

### Common Issues

1. **Pods not starting**: Check resource limits and requests
2. **Service connectivity**: Verify service names and ports
3. **Database connection**: Ensure PostgreSQL is running and accessible
4. **Kafka connectivity**: Check Zookeeper and Kafka pod status

### Debug Commands

```bash
# Describe pod to see events
kubectl describe pod <pod-name> -n messaging-app

# Check service endpoints
kubectl get endpoints -n messaging-app

# Check ConfigMaps
kubectl get configmaps -n messaging-app

# Check PersistentVolumeClaims
kubectl get pvc -n messaging-app
```

## Security Considerations

- All services run with minimal required permissions
- Database credentials are stored in ConfigMaps (consider using Secrets for production)
- Services communicate within the cluster using internal service names
- No external access except for the WebSocket service LoadBalancer

## Production Considerations

For production deployment:

1. Use Secrets instead of ConfigMaps for sensitive data
2. Implement proper resource limits and requests
3. Add ingress controllers for external access
4. Implement proper monitoring and logging
5. Use persistent storage with appropriate backup strategies
6. Consider using managed services for PostgreSQL and Kafka

# ws-service Deployment Guide

## Prerequisites
- Strimzi Kafka Operator installed in your cluster
- Kafka cluster deployed via Strimzi

## 1. Create Kafka Topics
Apply the following manifests to create the required Kafka topics:

```sh
kubectl apply -f k8s/messages-topic.yaml
kubectl apply -f k8s/persist-topic.yaml
```

## 2. Deploy ws-service
Apply the deployment manifest for ws-service:

```sh
kubectl apply -f k8s/ws-service-configmap.yaml
kubectl apply -f k8s/ws-service-deployment.yaml
kubectl apply -f k8s/ws-service-service.yaml
```

## 3. Verify
Check that the ws-service pod is running and the topics exist:

```sh
kubectl get pods -n messaging-app
kubectl get kafkatopics -n messaging-app
``` 