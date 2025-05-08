#!/bin/bash
# Script to setup the GCP environment for logs-based metrics project

# Exit on error
set -e

# Check for required environment variables
if [ -z "$PROJECT_ID" ]; then
  echo "PROJECT_ID environment variable is not set. Please set it first."
  echo "Example: export PROJECT_ID=\$(gcloud info --format='value(config.project)')"
  exit 1
fi

if [ -z "$REGION" ]; then
  echo "REGION environment variable is not set. Please set it first."
  echo "Example: export REGION=us-central1"
  exit 1
fi

if [ -z "$ZONE" ]; then
  echo "ZONE environment variable is not set. Please set it first."
  echo "Example: export ZONE=us-central1-a"
  exit 1
fi

echo "Setting up project $PROJECT_ID in region $REGION, zone $ZONE..."

# Set compute zone
gcloud config set compute/zone "$ZONE"

# Create GKE cluster
echo "Creating GKE cluster..."
gcloud container clusters create gmp-cluster --num-nodes=1 --zone "$ZONE"

# Create Docker repository in Artifact Registry
echo "Creating Docker repository..."
gcloud artifacts repositories create docker-repo \
    --repository-format=docker \
    --location="$REGION" \
    --description="Docker repository" \
    --project="$PROJECT_ID"

# Download and load the telemetry container image
echo "Downloading and loading container image..."
wget -q https://storage.googleapis.com/spls/gsp1024/flask_telemetry.zip
unzip -q flask_telemetry.zip
docker load -i flask_telemetry.tar

# Tag and push the image to Artifact Registry
echo "Tagging and pushing image to Artifact Registry..."
IMAGE_NAME="$REGION-docker.pkg.dev/$PROJECT_ID/docker-repo/flask-telemetry:v1"
docker tag gcr.io/ops-demo-330920/flask_telemetry:61a2a7aabc7077ef474eb24f4b69faeab47deed9 "$IMAGE_NAME"
docker push "$IMAGE_NAME"

# Get cluster credentials
echo "Getting cluster credentials..."
gcloud container clusters get-credentials gmp-cluster

# Create namespace
echo "Creating Kubernetes namespace..."
kubectl create ns gmp-test

# Download deployment files
echo "Downloading deployment files..."
wget -q https://storage.googleapis.com/spls/gsp1024/gmp_prom_setup.zip
unzip -q gmp_prom_setup.zip
cd gmp_prom_setup

# Update deployment file with the correct image path
echo "Updating deployment file with image path..."
sed -i "s|<ARTIFACT REGISTRY IMAGE NAME>|$IMAGE_NAME|g" flask_deployment.yaml

# Deploy the application
echo "Deploying the application..."
kubectl -n gmp-test apply -f flask_deployment.yaml
kubectl -n gmp-test apply -f flask_service.yaml

echo "Setup complete! Please wait a few minutes for all resources to be ready."
echo "Run the following command to check if your service is ready:"
echo "kubectl get services -n gmp-test"