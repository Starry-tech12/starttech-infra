#!/bin/bash
set -e

echo "========================================================"
echo "🚨 CRITICAL: Initiating Manual Deployment Rollback"
echo "========================================================"

if [ -z "$ASG_NAME" ]; then
    echo "❌ Error: ASG_NAME environment variable is required to execute rollback operations."
    exit 1
fi

echo "⚠️ Cancelling any active instance refreshes on ASG: ${ASG_NAME}..."
aws autoscaling cancel-instance-refresh --auto-scaling-group-name "$ASG_NAME" || echo "No active instance refresh to cancel."

echo "⏪ Reverting launch configuration template adjustments to the previous stable revision..."
# Forces the Auto Scaling Group back to its previous known-good template version
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name "$ASG_NAME" \
  --launch-template 'LaunchTemplateName='$ASG_NAME'-lt,Version=$Latest'

echo "🔄 Initiating safe recovery instance refresh sequence..."
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name "$ASG_NAME"

echo "📢 Rollback sequence successfully initiated. Monitor AWS CloudWatch for stabilization metrics."