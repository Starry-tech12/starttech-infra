#!/bin/bash
set -e
echo "Starting local execution for Infrastructure validation..."
cd "$(dirname "$0")/../terraform"
terraform init
terraform validate
terraform plan -out=tfplan
echo "Validation check completed. Run 'terraform apply tfplan' to execute manually."