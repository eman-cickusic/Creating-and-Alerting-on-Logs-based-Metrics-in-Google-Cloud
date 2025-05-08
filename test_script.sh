#!/bin/bash
# Script to test log-based metrics and alerts

# Exit on error
set -e

# Check if we have a deployment
if ! kubectl get ns gmp-test &> /dev/null; then
  echo "Namespace gmp-test not found. Please run setup.sh first."
  exit 1
fi

# Get the external IP of the service
echo "Getting service external IP..."
EXTERNAL_IP=""
while [ -z "$EXTERNAL_IP" ]; do
  EXTERNAL_IP=$(kubectl get services -n gmp-test -o jsonpath='{.items[*].status.loadBalancer.ingress[0].ip}')
  if [ -z "$EXTERNAL_IP" ]; then
    echo "Waiting for external IP to be assigned..."
    sleep 5
  fi
done

echo "Service external IP is $EXTERNAL_IP"

# Test if metrics endpoint is working
echo "Testing metrics endpoint..."
curl -s "$EXTERNAL_IP/metrics" | head -n 5

# Generate errors to trigger alerts
echo "Generating errors to trigger alerts..."
echo "This will run for 120 seconds..."
timeout 120 bash -c -- "while true; do curl -s $EXTERNAL_IP/error > /dev/null; sleep \$((RANDOM % 4)) ; done"

echo "Error generation complete!"
echo "Please check the following in Google Cloud Console:"
echo "1. Logs Explorer -> Look for ERROR severity logs"
echo "2. Monitoring -> Alerting -> Check for triggered alerts"
echo "3. Log-based Metrics -> Check 'hello-app-error' metric"