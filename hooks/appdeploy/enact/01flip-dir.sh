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

set -ex

. /opt/elasticbeanstalk/hooks/common.sh

EB_CONFIG_APP_CURRENT=$(/opt/elasticbeanstalk/bin/get-config container -k app_deploy_dir)

EB_CONFIG_APP_STAGING=$(/opt/elasticbeanstalk/bin/get-config container -k app_staging_dir)
[ -z "$EB_CONFIG_APP_STAGING" ] && EB_CONFIG_APP_STAGING=/var/app/staging

if [ -d $EB_CONFIG_APP_CURRENT ]; then
	mv $EB_CONFIG_APP_CURRENT $EB_CONFIG_APP_CURRENT.old
fi

mv $EB_CONFIG_APP_STAGING $EB_CONFIG_APP_CURRENT

nohup rm -rf $EB_CONFIG_APP_CURRENT.old >/dev/null 2>&1 &
