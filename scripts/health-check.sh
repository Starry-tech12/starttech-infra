#!/bin/bash
set -e
echo "Querying load balanced API target endpoint health..."
STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$1/health || echo "Failed")
if [ "$STATUS" = "200" ]; then
    echo "Service is healthy and routing traffic perfectly."
    exit 0
else
    echo "Target endpoint returned anomalous non-200 state code: $STATUS"
    exit 1
fi