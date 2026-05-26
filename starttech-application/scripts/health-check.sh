#!/bin/bash
echo "========================================================"
echo "🩺 Executing Automated Endpoint Verification Checks"
echo "========================================================"

if [ -z "$ALB_HEALTH_URL" ]; then
    echo "❌ Error: ALB_HEALTH_URL environment variable is not defined."
    exit 1
fi

MAX_ATTEMPTS=6
ATTEMPT_COUNT=1
TIMEOUT_DELAY=15

echo "🔗 Target Verification Endpoint: ${ALB_HEALTH_URL}"

while [ $ATTEMPT_COUNT -le $MAX_ATTEMPTS ]; do
    echo "🔄 Attempting Health Ping [${ATTEMPT_COUNT}/${MAX_ATTEMPTS}]..."
    
    # Send a request to the health endpoint, checking for an HTTP 200 status code
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$ALB_HEALTH_URL") || true
    
    if [ "$HTTP_STATUS" = "200" ]; then
        echo "🎉 Success! The Application Load Balancer returned an HTTP 200 OK."
        exit 0
    else
        echo "⚠️ Target instance returned non-operational code: [${HTTP_STATUS}]. Retrying in ${TIMEOUT_DELAY}s..."
        ATTEMPT_COUNT=$((ATTEMPT_COUNT + 1))
        sleep $TIMEOUT_DELAY
    fi
done

echo "❌ Failure Boundary Reached: The deployed infrastructure failed validation check parameters."
exit 1