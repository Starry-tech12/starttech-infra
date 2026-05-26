#!/bin/bash
set -e
echo "Manually pushing backend container image tag..."
cd "$(dirname "$0")/../backend"
docker build -t $1/starttech-backend:latest .
docker push $1/starttech-backend:latest