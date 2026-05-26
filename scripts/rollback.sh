#!/bin/bash
set -e
echo "Initiating emergency fallback operations..."
ASG_NAME=$(aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[?contains(AutoScalingGroupName, 'starttech-asg')].AutoScalingGroupName" --output text)
aws autoscaling cancel-instance-refresh --auto-scaling-group-name "$ASG_NAME" || echo "No active deployment refresh to cancel."
echo "Rollback sequence handled."