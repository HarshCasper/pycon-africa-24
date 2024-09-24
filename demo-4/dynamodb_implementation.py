import os
import boto3
from PIL import Image
import tempfile
import traceback
import uuid
from datetime import datetime

# Use the correct endpoint URL for LocalStack
s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

MAX_DIMENSIONS = (400, 400)
DYNAMODB_TABLE = 'ImageMetaData'

def resize_image(image_path, resized_path, original_format):
    with Image.open(image_path) as image:
        # Calculate the thumbnail size
        width, height = image.size
        max_width, max_height = MAX_DIMENSIONS
        if width > max_width or height > max_height:
            ratio = max(width / max_width, height / max_height)
            width = int(width / ratio)
            height = int(height / ratio)
        size = (width, height)

        # Generate the resized image
        image.thumbnail(size)

        # Convert image to RGB if necessary
        if image.mode in ("RGBA", "P"):
            image = image.convert("RGB")

        # Save the resized image
        image.save(resized_path, format=original_format)

def lambda_handler(event, context):
    try:
        # Debugging: Print the event
        print("Received event:", event)

        # Get bucket and object key from the event
        source_bucket = event['Records'][0]['s3']['bucket']['name']
        source_key = event['Records'][0]['s3']['object']['key']
        destination_bucket = 'resized-images'

        print(f"Source bucket: {source_bucket}, Source key: {source_key}")

        with tempfile.TemporaryDirectory() as tmpdir:
            download_path = os.path.join(tmpdir, source_key)
            # Extract the filename and extension
            base_filename, ext = os.path.splitext(source_key)
            resized_filename = f"resized-{base_filename}{ext}"
            upload_path = os.path.join(tmpdir, resized_filename)

            # Download the image from S3
            print("Downloading image...")
            s3_client.download_file(source_bucket, source_key, download_path)
            print("Image downloaded to", download_path)

            # Determine the image format
            with Image.open(download_path) as image:
                original_format = image.format
            print("Original image format:", original_format)

            # Resize the image
            print("Resizing image...")
            resize_image(download_path, upload_path, original_format)
            print("Image resized and saved to", upload_path)

            # Upload the resized image to the destination bucket
            print("Uploading resized image...")
            s3_client.upload_file(upload_path, destination_bucket, resized_filename)
            print("Resized image uploaded to", destination_bucket)

            # Store metadata in DynamoDB
            print("Storing metadata in DynamoDB...")
            table = dynamodb.Table(DYNAMODB_TABLE)
            table.put_item(
                Item={
                    'ImageID': str(uuid.uuid4()),
                    'OriginalBucket': source_bucket,
                    'OriginalKey': source_key,
                    'ResizedBucket': destination_bucket,
                    'ResizedKey': resized_filename,
                    'Timestamp': datetime.utcnow().isoformat()
                }
            )
            print("Metadata stored in DynamoDB.")

        return {
            'statusCode': 200,
            'body': f"Image {source_key} resized and uploaded to {destination_bucket}"
        }
    except Exception as e:
        print("Error occurred:", e)
        traceback.print_exc()
        raise e
