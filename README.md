# Creating and Alerting on Logs-based Metrics in Google Cloud

This repository documents the implementation of log-based metrics and alerts in Google Cloud Platform. It provides step-by-step instructions for setting up log-based monitoring for applications running in Google Kubernetes Engine (GKE).

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Setup](#setup)
- [Task 1: Deploy a GKE Cluster](#task-1-deploy-a-gke-cluster)
- [Task 2: Create a Log-based Alert](#task-2-create-a-log-based-alert)
- [Task 3: Create a Docker Repository](#task-3-create-a-docker-repository)
- [Task 4: Deploy a Simple Application with Metrics](#task-4-deploy-a-simple-application-with-metrics)
- [Task 5: Create a Log-based Metric](#task-5-create-a-log-based-metric)
- [Task 6: Create a Metrics-based Alert](#task-6-create-a-metrics-based-alert)
- [Task 7: Test by Generating Errors](#task-7-test-by-generating-errors)
- [Repository Contents](#repository-contents)
- [Troubleshooting](#troubleshooting)
- [References](#references)

## Overview

Log-based metrics are Cloud Monitoring metrics that are based on the content of log entries. These metrics can help you:
- Identify trends
- Extract numeric values from logs
- Set up alerts when specific log entries occur

There are two types of log-based metrics:
- **System-defined log-based metrics**: Provided by Cloud Logging for all Google Cloud projects
- **User-defined log-based metrics**: Created by you to track specific events in your project

## Video

https://youtu.be/pnGDxoaD-Dw


## Prerequisites

- Google Cloud account
- Basic knowledge of Google Cloud Platform
- Basic knowledge of Kubernetes
- `gcloud` CLI installed
- `kubectl` installed

## Setup

Before beginning, make sure to:
1. Log in to your Google Cloud account
2. Set your project ID and compute zone:

```bash
gcloud config set compute/zone YOUR_ZONE
export PROJECT_ID=$(gcloud info --format='value(config.project)')
```

## Task 1: Deploy a GKE Cluster

Create a standard Google Kubernetes Engine cluster to host our application:

```bash
gcloud container clusters create gmp-cluster --num-nodes=1 --zone YOUR_ZONE
```

This will create a single-node GKE cluster named `gmp-cluster`.

## Task 2: Create a Log-based Alert

This alert will notify you when a VM stops running:

1. Navigate to **Logs Explorer** in the Google Cloud Console
2. Enter the following query:
   ```
   resource.type="gce_instance" protoPayload.methodName="v1.compute.instances.stop"
   ```
3. Click **Create log alert**
4. Configure the alert:
   - Name: `stopped vm`
   - Notification frequency: 5 min
   - Autoclose duration: 1 hr
5. Add notification channels as needed (email, SMS, etc.)
6. Save the alert policy

### Testing the Log-based Alert

You can test this alert by:
1. Stopping a VM instance
2. Checking the Logging section to see if your alert registers

## Task 3: Create a Docker Repository

Create a private Docker repository in Artifact Registry:

```bash
gcloud artifacts repositories create docker-repo \
    --repository-format=docker \
    --location=YOUR_REGION \
    --description="Docker repository" \
    --project=YOUR_PROJECT_ID
```

Load and push a pre-built image:

```bash
wget https://storage.googleapis.com/spls/gsp1024/flask_telemetry.zip
unzip flask_telemetry.zip
docker load -i flask_telemetry.tar

# Tag the image
docker tag gcr.io/ops-demo-330920/flask_telemetry:61a2a7aabc7077ef474eb24f4b69faeab47deed9 \
    YOUR_REGION-docker.pkg.dev/YOUR_PROJECT_ID/docker-repo/flask-telemetry:v1

# Push to Artifact Registry
docker push YOUR_REGION-docker.pkg.dev/YOUR_PROJECT_ID/docker-repo/flask-telemetry:v1
```

## Task 4: Deploy a Simple Application with Metrics

Deploy a Python Flask application that emits metrics:

```bash
# Authenticate with the cluster
gcloud container clusters get-credentials gmp-cluster

# Create a namespace
kubectl create ns gmp-test

# Download and extract deployment files
wget https://storage.googleapis.com/spls/gsp1024/gmp_prom_setup.zip
unzip gmp_prom_setup.zip
cd gmp_prom_setup

# Update the deployment file with your image path
# Edit flask_deployment.yaml and replace <ARTIFACT REGISTRY IMAGE NAME> with:
# YOUR_REGION-docker.pkg.dev/YOUR_PROJECT_ID/docker-repo/flask-telemetry:v1

# Deploy the application
kubectl -n gmp-test apply -f flask_deployment.yaml
kubectl -n gmp-test apply -f flask_service.yaml

# Verify the deployment
kubectl get services -n gmp-test

# Test metrics endpoint
curl $(kubectl get services -n gmp-test -o jsonpath='{.items[*].status.loadBalancer.ingress[0].ip}')/metrics
```

## Task 5: Create a Log-based Metric

Create a metric to track application errors:

1. Go to **Logs Explorer**
2. Click **Create metric**
3. Configure:
   - Metric type: Counter
   - Name: `hello-app-error`
   - Filter:
     ```
     severity=ERROR
     resource.labels.container_name="hello-app"
     textPayload: "ERROR: 404 Error page not found"
     ```
4. Click **Create metric**

## Task 6: Create a Metrics-based Alert

Create an alert based on the log-based metric:

1. Go to **Log-based Metrics**
2. Find `hello-app-error` and select **Create alert from metric**
3. Configure:
   - Rolling window: 2 min
   - Set notification channels
   - Name: `log based metric alert`
4. Click **Create Policy**

## Task 7: Test by Generating Errors

Generate errors to trigger your metric and alert:

```bash
timeout 120 bash -c -- 'while true; do curl $(kubectl get services -n gmp-test -o jsonpath="{.items[*].status.loadBalancer.ingress[0].ip}")/error; sleep $((RANDOM % 4)) ; done'
```

Then check:
1. Logs Explorer for ERROR severity logs
2. Monitoring > Alerting for triggered alerts

## Repository Contents

- `README.md` - This guide
- `flask_deployment.yaml` - Kubernetes deployment file for the Flask application
- `flask_service.yaml` - Kubernetes service file for the Flask application
- `/scripts` - Helper scripts for setup and testing

## Troubleshooting

- **Missing metrics**: Ensure your application is running and the metrics endpoint is accessible
- **No alerts triggered**: Check your filter criteria and test directly in Logs Explorer
- **Deployment issues**: Verify cluster credentials and check pod status with `kubectl get pods -n gmp-test`

## References

- [Cloud Logging Documentation](https://cloud.google.com/logging/docs)
- [Cloud Monitoring Documentation](https://cloud.google.com/monitoring/docs)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Artifact Registry Documentation](https://cloud.google.com/artifact-registry/docs)
