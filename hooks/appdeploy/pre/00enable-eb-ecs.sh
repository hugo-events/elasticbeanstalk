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

. /opt/elasticbeanstalk/hooks/common.sh

# safeguard to make sure the eb-ecs daemon is enabled
mv /etc/init/eb-ecs.conf.disabled /etc/init/eb-ecs.conf
initctl reload-configuration

# no clean up if there isn't a running container to avoid re-pulling cached images
# https://docs.docker.com/reference/commandline/ps/
RUNNING_DOCKER_CONTAINERS=$(docker ps -a -q -f status=running)

if [ -n "$RUNNING_DOCKER_CONTAINERS" ]; then
	save_docker_image_names
	docker rm `docker ps -aq` > /dev/null 2>&1
	docker rmi `docker images -aq` > /dev/null 2>&1
	restore_docker_image_names
fi

# return true to let hook pass
true