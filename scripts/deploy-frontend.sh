#!/bin/bash
set -e
echo "Building and shipping frontend manually..."
cd "$(dirname "$0")/../frontend"
npm install
npm run build
aws s3 sync build/ s3://$1