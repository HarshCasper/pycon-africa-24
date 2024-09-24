# Add the same set of commands from demo-2 & demo-3 except the Lambda create command 

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

awslocal dynamodb create-table \
    --table-name ImageMetaData \
    --attribute-definitions AttributeName=ImageID,AttributeType=S \
    --key-schema AttributeName=ImageID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5

awslocal dynamodb list-tables

awslocal dynamodb scan --table-name ImageMetaData
