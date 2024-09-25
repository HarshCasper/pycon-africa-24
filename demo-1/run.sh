#!/bin/bash

awslocal s3api create-bucket --bucket original-images
awslocal s3api create-bucket --bucket resized-images

# macOS
docker run --platform linux/x86_64 --rm -v "$PWD":/var/task "public.ecr.aws/sam/build-python3.11" /bin/sh -c "pip3 install -r requirements.txt -t libs; exit"

# Linux/Windows
# pip3 install -r requirements.txt --platform manylinux2014_x86_64 --only-binary=:all: -t package

cd libs && zip -r ../lambda.zip . && cd ..
zip lambda.zip lambda_function.py
sudo rm -rf libs

awslocal lambda create-function \
    --function-name ImageResizerFunction \
    --runtime python3.11 \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://lambda.zip \
    --role arn:aws:iam::000000000000:role/lambda-role \
    --timeout 60

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

awslocal s3 cp image.png s3://original-images/image.png
awslocal s3 cp image.jpg s3://original-images/image.jpg

awslocal s3 ls s3://resized-images
awslocal s3 ls s3://original-images

awslocal s3 cp s3://resized-images/resized-image.png resized-image.png
