#!/bin/bash
#==============================================================================
# Copyright 2012 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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

# as of Docker 1.5 this is safe to do since a failed rmi on images (directly)
# used by running containers do not get incorrectly untagged any more

# no clean up if there is no exited containers
# https://docs.docker.com/reference/commandline/ps/
CURRENT_DOCKER_CONTAINERS=$(docker ps -aq)

if [ -n "$CURRENT_DOCKER_CONTAINERS" ]; then
	save_docker_image_names
	docker rm `docker ps -aq` > /dev/null 2>&1
	docker rmi `docker images -aq` > /dev/null 2>&1
	restore_docker_image_names
fi

# the above commands should return error codes since we still have running
# containers, return 0 to make command processor happy
true