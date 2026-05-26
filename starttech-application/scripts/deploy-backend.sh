#!/bin/bash
set -e

echo "========================================================"
echo "🛠️ Initiating Backend Multi-Instance Infrastructure Rolling Update"
echo "========================================================"

if [ -z "$ASG_NAME" ]; then
    echo "❌ Error: ASG_NAME environment variable is required but missing."
    exit 1
fi

echo "🔄 Triggering instance refresh across Auto Scaling Group: ${ASG_NAME}..."
REFRESH_ID=$(aws autoscaling start-instance-refresh \
  --auto-scaling-group-name "$ASG_NAME" \
  --preferences '{"MinHealthyPercentage": 50}' \
  --query 'InstanceRefreshId' \
  --output text)

echo "⏳ Monitoring deployment status for Instance Refresh ID: ${REFRESH_ID}..."

while true; do
    STATUS=$(aws autoscaling describe-instance-refreshes \
      --auto-scaling-group-name "$ASG_NAME" \
      --instance-refresh-ids "$REFRESH_ID" \
      --query 'InstanceRefreshes[0].Status' \
      --output text)
    
    echo "📊 Current Instance Refresh Lifecycle State: [${STATUS}]"
    
    if [ "$STATUS" = "Successful" ]; then
        echo "✅ ASG Instance rolling upgrade successfully completed!"
        break
    elif [ "$STATUS" = "Failed" ] || [ "$STATUS" = "Cancelled" ]; then
        echo "❌ Critical Error: The ASG rolling infrastructure update has tracking status: ${STATUS}."
        exit 1
    fi
    
    sleep 20
done

# Run the system verification check right after the instance upgrade completes
../scripts/health-check.sh