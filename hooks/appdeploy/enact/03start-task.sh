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

RETRY=0
until initctl start eb-ecs EB_EVENT_FILE=$EB_EVENT_FILE; do
	if [ -f /etc/elasticbeanstalk/.eb-ecs-start-no-retry ]; then # non-retryable error
		rm -f /etc/elasticbeanstalk/.eb-ecs-start-no-retry
		exit 2
	fi

	warn "Failed to start ECS task, retrying..."
	RETRY=$((RETRY + 1))
	sleep 3

	if [ $RETRY -gt 1 ]; then
		error_exit "Failed to start ECS task after retrying $RETRY times." 1
	fi
done
