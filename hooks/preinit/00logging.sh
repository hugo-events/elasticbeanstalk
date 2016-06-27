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

# eb-ecs-mgr logs
/opt/elasticbeanstalk/bin/log-conf -n eb-ecs-mgr -l'/var/log/eb-ecs-mgr.log'

# ecs-init/ecs-agent logs (the agent does its own rotation, do not configure logrotate)
echo '/var/log/ecs/ecs-agent.log.*' | tee /opt/elasticbeanstalk/tasks/{bundlelogs,publishlogs,systemtaillogs,taillogs}.d/ecs-agent.conf
echo '/var/log/ecs/ecs-init.log.*' | tee /opt/elasticbeanstalk/tasks/{bundlelogs,publishlogs,systemtaillogs,taillogs}.d/ecs-init.conf

# docker events/ps
/opt/elasticbeanstalk/bin/log-conf -n docker -l'/var/log/docker-events.log,/var/log/docker-ps.log'

# docker daemon logs
/opt/elasticbeanstalk/bin/log-conf -n dockerdaemon -l'/var/log/docker'

# docker container logs
/opt/elasticbeanstalk/bin/log-conf -n applogs-stdouterr -l'/var/log/containers/*-stdouterr.log'
