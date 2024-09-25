#!/bin/bash

cd demo-1

awslocal s3api create-bucket --bucket original-images
awslocal s3api create-bucket --bucket resized-images

# To have the dependencies available in hot reload mode
docker run --platform linux/x86_64 --rm -v "$PWD":/var/task "public.ecr.aws/sam/build-python3.11" /bin/sh -c "pip3 install -r requirements.txt -t .; exit"

awslocal lambda create-function \
    --function-name ImageResizerFunction \
    --runtime python3.11 \
    --handler lambda_function.lambda_handler \
    --code S3Bucket="hot-reload",S3Key="${PWD}" \
    --role arn:aws:iam::000000000000:role/lambda-role \
    --timeout 60

# Remember to add the bucket notification configuration

awslocal lambda wait function-active-v2 --function-name ImageResizerFunction

awslocal s3api put-bucket-notification-configuration \
    --bucket original-images \
    --notification-configuration '{
        "LambdaFunctionConfigurations": [
            {
                "LambdaFunctionArn": "arn:aws:lambda:us-east-1:000000000000:function:ImageResizerFunction",
                "Events": ["s3:ObjectCreated:*"]
            }
        ]
    }'

awslocal dynamodb create-table \
    --table-name ImageMetaData \
    --attribute-definitions AttributeName=ImageID,AttributeType=S \
    --key-schema AttributeName=ImageID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5

awslocal s3 cp image.png s3://original-images/image.png

awslocal dynamodb list-tables

awslocal dynamodb scan --table-name ImageMetaData
