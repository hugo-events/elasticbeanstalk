#!/bin/bash
#==============================================================================
# Copyright 2015 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the "License"). You may not use
# this file except in compliance with the License. A copy of the License is
# located at
#
#       http://aws.amazon.com/asl/
#
# or in the "license" file accompanying this file. This file is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
# implied. See the License for the specific language governing permissions
# and limitations under the License.
#==============================================================================

set -e

. /opt/elasticbeanstalk/hooks/common.sh

EB_CONFIG_APP_CURRENT=$(/opt/elasticbeanstalk/bin/get-config container -k app_deploy_dir)
EB_SUPPORT_FILES=$(/opt/elasticbeanstalk/bin/get-config container -k support_files_dir)

cd $EB_CONFIG_APP_CURRENT

S3_BUCKET=`cat Dockerrun.aws.json | jq -r .authentication.bucket`
S3_KEY=`cat Dockerrun.aws.json | jq -r .authentication.key`

# retry with older syntax (upper case)
if [ -z "$S3_BUCKET" ] || [ "$S3_BUCKET" = "null" ]; then
	S3_BUCKET=`cat Dockerrun.aws.json | jq -r .Authentication.Bucket`
	S3_KEY=`cat Dockerrun.aws.json | jq -r .Authentication.Key`	
fi

# still not found? no need for auth
if [ -z "$S3_BUCKET" ] || [ "$S3_BUCKET" = "null" ]; then
	exit 0
fi

CURRENT_AUTH_TYPE=`cat /etc/ecs/ecs.config | egrep '^ECS_ENGINE_AUTH_TYPE' | cut -c 22-`
CURRENT_AUTH_DATA=`cat /etc/ecs/ecs.config | egrep '^ECS_ENGINE_AUTH_DATA' | cut -c 22-`

NEW_AUTH_TYPE=dockercfg
if ! NEW_AUTH_DATA=`$EB_SUPPORT_FILES/download_auth.py "$S3_BUCKET" "$S3_KEY"`; then
	error_exit "Failed to download authentication credentials $S3_KEY from $S3_BUCKET" 1
fi

# minimize the JSON to one line
if ! NEW_AUTH_DATA=`echo "$NEW_AUTH_DATA" | jq -c .`; then
	error_exit "Authentication credentials are not in JSON format as expected. Please generate the credentials using 'docker login'." 1
fi

# credentials did not change
if [ "$NEW_AUTH_TYPE" = "$CURRENT_AUTH_TYPE" ] && [ "$NEW_AUTH_DATA" = "$CURRENT_AUTH_DATA" ]; then
	exit 0
fi

# update credentials
sed -i "/^ECS_ENGINE_AUTH_TYPE=.*\$/d" /etc/ecs/ecs.config
sed -i "/^ECS_ENGINE_AUTH_DATA=.*\$/d" /etc/ecs/ecs.config
echo "ECS_ENGINE_AUTH_TYPE=$NEW_AUTH_TYPE" >> /etc/ecs/ecs.config
echo "ECS_ENGINE_AUTH_DATA=$NEW_AUTH_DATA" >> /etc/ecs/ecs.config

# restart ECS agent (temporarily disable eb-ecs since we will start it in the next step)
mv /etc/init/eb-ecs.conf /etc/init/eb-ecs.conf.disabled
initctl reload-configuration

if initctl status ecs | grep -q 'ecs start/'; then
	initctl stop ecs
fi

if ! initctl start ecs; then
	mv /etc/init/eb-ecs.conf.disabled /etc/init/eb-ecs.conf
	initctl reload-configuration
	error_exit "Failed to start ECS agent with new authentication credentials" 1
fi

mv /etc/init/eb-ecs.conf.disabled /etc/init/eb-ecs.conf
initctl reload-configuration
