#!/usr/bin/env python

from boto.s3 import connect_to_region
from boto.s3.key import Key
from boto.utils import get_instance_identity
from sys import argv
from os import environ

environ['S3_USE_SIGV4'] = 'true'

def download_auth(bucket_name, key_name, region):
    conn = connect_to_region(region, calling_format = 'boto.s3.connection.OrdinaryCallingFormat')
    bucket = conn.get_bucket(bucket_name, validate = False)
    key = Key(bucket = bucket, name = key_name)
    print key.get_contents_as_string()

if __name__ == '__main__':
    download_auth(argv[1], argv[2], get_instance_identity()['document']['region'])
