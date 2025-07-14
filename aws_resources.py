#!/usr/bin/env python3
import sys
import boto3
from botocore.exceptions import ClientError

AWS_PROFILE = 'dev'
REGION = 'us-east-1'

session = boto3.Session(profile_name=AWS_PROFILE, region_name=REGION)
ec2 = session.client('ec2')


def create_s3_bucket(bucket_name):
    try:
        ec2.create_bucket(Bucket=bucket_name)
        print(f"✔️  Bucket S3 '{bucket_name}' creado")
    except ClientError as e:
        if e.response['Error']['Code'] == 'BucketAlreadyOwnedByYou':
            print(f"🔔 Bucket '{bucket_name}' ya existe y es tuyo")
        else:
            print(f"❌ Error creando Bucket: {e}")
            sys.exit(1)


def delete_s3_bucket(bucket_name):
    try:
        ec2.delete_bucket(Bucket=bucket_name)
        print(f"✔️  Bucket S3 '{bucket_name}' eliminado")
    except ClientError as e:
        print(f"❌ Error eliminando Bucket: {e}")
        sys.exit(1)


if __name__ == '__main__':
    if len(sys.argv) != 3 or sys.argv[1] not in ('create', 'delete'):
        print("Uso: aws_resources.py [create|delete] <bucket_name>")
        sys.exit(1)
    action, name = sys.argv[1], sys.argv[2]
    if action == 'create':
        create_s3_bucket(name)
    else:
        delete_s3_bucket(name)