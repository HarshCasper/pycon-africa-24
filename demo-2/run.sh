#!/bin/bash

awslocal sns create-topic --name failed-resize-topic

awslocal ses verify-email-identity --email my-email@example.com

awslocal sns subscribe \
    --topic-arn arn:aws:sns:us-east-1:000000000000:failed-resize-topic \
    --protocol email \
    --notification-endpoint my-email@example.com

# Take the previous example

awslocal lambda update-function-configuration \
    --function-name ImageResizerFunction \
    --dead-letter-config TargetArn=arn:aws:sns:us-east-1:000000000000:failed-resize-topic

awslocal lambda put-function-event-invoke-config \
    --function-name ImageResizerFunction \
    --maximum-event-age-in-seconds 3600 \
    --maximum-retry-attempts 0

# Remember to add the S3 Bucket Notification Configuration

awslocal s3 cp check.txt s3://original-images/check.png

curl -s http://localhost.localstack.cloud:4566/_aws/ses | jq
