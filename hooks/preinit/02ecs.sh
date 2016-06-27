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

set -ex

. /opt/elasticbeanstalk/hooks/common.sh

EB_CONFIG_ECS_CLUSTER=$(/opt/elasticbeanstalk/bin/get-config container -k ecs_cluster)
EB_CONFIG_ECS_REGION=$(/opt/elasticbeanstalk/bin/get-config container -k ecs_region)
EB_CONFIG_SUPPORT_FILES_DIR=$(/opt/elasticbeanstalk/bin/get-config container -k support_files_dir)

if ! is_baked ecs_agent; then
	EB_CONFIG_ECS_AGENT_OVERRIDE=$(/opt/elasticbeanstalk/bin/get-config container -k ecs_agent_override)
	if [ -n "$EB_CONFIG_ECS_AGENT_OVERRIDE" ]; then
		curl -sS -o /var/cache/ecs/ecs-agent.tar "$EB_CONFIG_ECS_AGENT_OVERRIDE"
		echo 1 > /var/cache/ecs/state
	fi
	/usr/libexec/amazon-ecs-init pre-start
fi

aws configure set default.output json
aws configure set default.region $EB_CONFIG_ECS_REGION

# start the ECS agent
echo "ECS_CLUSTER=$EB_CONFIG_ECS_CLUSTER" >> /etc/ecs/ecs.config
initctl status ecs | grep -q 'ecs start/' || initctl start ecs

# now wait for this EC2 instance to be registered
TIMEOUT=120
INSTANCE_ARN=`curl http://localhost:51678/v1/metadata | jq -r .ContainerInstanceArn`
until [ -n "$INSTANCE_ARN" ] && [ "$INSTANCE_ARN" != "null" ]; do
	sleep 1
	TIMEOUT=$(( TIMEOUT - 1 ))
	if [ $TIMEOUT -le 0 ]; then
		error_exit "Instance failed to register with ECS." 1
	fi

	INSTANCE_ARN=`curl http://localhost:51678/v1/metadata | jq -r .ContainerInstanceArn`
done

cp $EB_CONFIG_SUPPORT_FILES_DIR/init/eb-ecs.conf /etc/init/

cp $EB_CONFIG_SUPPORT_FILES_DIR/init/eb-docker-events.conf /etc/init/
initctl start eb-docker-events 2>&1 | grep -q running
