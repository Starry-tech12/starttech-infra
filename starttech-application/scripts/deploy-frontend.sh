#!/bin/bash
set -e # Terminate script immediately if any individual command fails

echo "========================================================"
echo "🚀 Starting Frontend Deployment Process"
echo "========================================================"

if [ -z "$S3_BUCKET_NAME" ] || [ -z "$CLOUDFRONT_DISTRIBUTION_ID" ]; then
    echo "❌ Error: S3_BUCKET_NAME or CLOUDFRONT_DISTRIBUTION_ID variables are unbound."
    exit 1
fi

echo # Notice the path points cleanly to the frontend build folder relative to the root execution context
aws s3 sync ./build/ s3://"${S3_BUCKET_NAME}"/ --delete

echo "🧹 Invalidating CloudFront cache distribution: ${CLOUDFRONT_DISTRIBUTION_ID}..."
# Fires a cache-busting entry to clear the CDN edge nodes for instant updates
aws cloudfront create-invalidation \
  --distribution-id "${CLOUDFRONT_DISTRIBUTION_ID}" \
  --paths "/*"

echo "✅ Frontend deployment pipeline actions completed successfully!"