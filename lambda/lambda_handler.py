import boto3
import logging

# Initialize the S3 client
s3 = boto3.client('s3')
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Lambda function to re-replicate specific deleted files.
    Triggered by S3 ObjectRemoved events.
    """
    try:
        # Extract bucket and object key from the event
        bucket_name = event['detail']['bucket']['name']
        object_key = event['detail']['object']['key']

        # List of specific files to monitor for deletions
        specific_files = [
            'path/to/specific-file-1.txt',
            'path/to/specific-file-2.json'
        ]

        if object_key not in specific_files:
            logger.info(f"File '{object_key}' is not in the list of specific files. Ignoring.")
            return {
                'statusCode': 200,
                'body': f"Ignored file: {object_key}"
            }

        source_bucket = 'source-bucket-name'

        # Copy the file back from the source bucket
        logger.info(f"Re-replicating file: {object_key}")
        s3.copy_object(
            CopySource={'Bucket': source_bucket, 'Key': object_key},
            Bucket=bucket_name,
            Key=object_key
        )
        
        logger.info(f"Successfully re-replicated file: {object_key}")
        return {
            'statusCode': 200,
            'body': f"Re-replicated file: {object_key}"
        }

    except Exception as e:
        logger.error(f"Error in re-replicating file: {str(e)}")
        return {
            'statusCode': 500,
            'body': f"Failed to re-replicate file. Error: {str(e)}"
        }
