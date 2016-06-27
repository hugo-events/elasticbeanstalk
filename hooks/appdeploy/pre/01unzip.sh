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

EB_CONFIG_APP_SOURCE=$(/opt/elasticbeanstalk/bin/get-config container -k source_bundle)
EB_CONFIG_APP_CURRENT=$(/opt/elasticbeanstalk/bin/get-config container -k app_deploy_dir)
EB_SUPPORT_FILES=$(/opt/elasticbeanstalk/bin/get-config container -k support_files_dir)
EB_CONFIG_DOCKER_LOG_HOST_DIR=$(/opt/elasticbeanstalk/bin/get-config container -k host_log_dir)

EB_CONFIG_APP_STAGING=$(/opt/elasticbeanstalk/bin/get-config container -k app_staging_dir)
[ -z "$EB_CONFIG_APP_STAGING" ] && EB_CONFIG_APP_STAGING=/var/app/staging

rm -rf $EB_CONFIG_APP_STAGING
mkdir -p $EB_CONFIG_APP_STAGING

APP_BUNDLE_TYPE=`file -m $EB_SUPPORT_FILES/beanstalk-magic -b --mime-type $EB_CONFIG_APP_SOURCE`

if [ "$APP_BUNDLE_TYPE" = "application/zip" ]; then
	unzip -o -d $EB_CONFIG_APP_STAGING $EB_CONFIG_APP_SOURCE || error_exit "Failed to unzip source bundle, abort deployment" 1
else
	cp $EB_CONFIG_APP_SOURCE $EB_CONFIG_APP_STAGING/Dockerrun.aws.json
fi

for CONTAINER in `cat $EB_CONFIG_APP_STAGING/Dockerrun.aws.json | jq -r .containerDefinitions[].name`; do
	CONTAINER_LOG_DIR=$EB_CONFIG_DOCKER_LOG_HOST_DIR/$CONTAINER

	mkdir -p $CONTAINER_LOG_DIR
	# need chmod since customer app may run as non-root and the user they run as is nondeterminstic
	chmod 777 $CONTAINER_LOG_DIR

	/opt/elasticbeanstalk/bin/log-conf -n applogs-$CONTAINER -l"$CONTAINER_LOG_DIR/*.log" -r size=1M,rotate=5
	/opt/elasticbeanstalk/bin/log-conf -n applogs-$CONTAINER-rotated -l"$CONTAINER_LOG_DIR.log*" -t bundlelogs
done
