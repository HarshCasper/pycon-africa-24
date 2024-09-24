import os
import pytest
import boto3
from time import sleep

# Setup S3 client for LocalStack
s3_client = boto3.client(
    's3',
    endpoint_url="http://localhost.localstack.cloud:4566/",
    aws_access_key_id="test",
    aws_secret_access_key="test",
    region_name="us-east-1"
)

def upload_image(image_path):
    """Upload the original image to the S3 bucket."""
    with open(image_path, "rb") as f:
        s3_client.upload_fileobj(f, 'original-images', 'image.png')

def download_image(bucket, image_name, destination_path):
    """Download image from S3."""
    with open(destination_path, 'wb') as f:
        s3_client.download_fileobj(bucket, image_name, f)

def wait_for_resized_image(bucket, key, timeout=60, interval=5):
    """Wait for the resized image to appear in S3."""
    for _ in range(timeout // interval):
        objects = s3_client.list_objects_v2(Bucket=bucket)
        if 'Contents' in objects:
            for obj in objects['Contents']:
                if obj['Key'] == key:
                    return True
        sleep(interval)
    return False

def test_image_resize():
    original_image_path = "demo-2/image.png"
    resized_image_path = "resized-image.png"
    
    # Upload the original image
    upload_image(original_image_path)
    
    # Wait for the resized image to appear
    assert wait_for_resized_image('resized-images', 'resized-image.png'), "Resized image not found in time"

    # Download both original and resized images
    download_image('original-images', 'image.png', '/tmp/original_image.png')
    download_image('resized-images', 'resized-image.png', '/tmp/resized_image.png')

    # Check file sizes to ensure resized image is smaller
    original_size = os.path.getsize('/tmp/original_image.png')
    resized_size = os.path.getsize('/tmp/resized_image.png')

    assert resized_size < original_size, "Resized image is not smaller than the original image"
