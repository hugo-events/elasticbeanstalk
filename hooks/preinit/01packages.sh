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

chkconfig cfn-hup on

if ! is_baked ecs_packages; then
    echo "Running on unbaked AMI, installing packages."
	yum install -y docker docker-storage-setup jq aws-cli ecs-init

	# RPM overrides
	EB_CONFIG_RPM_OVERRIDES=$(/opt/elasticbeanstalk/bin/get-config container -k rpm_overrides)
	if [ -n "$EB_CONFIG_RPM_OVERRIDES" ]; then
		for RPM in $EB_CONFIG_RPM_OVERRIDES; do
			curl -sS -o /tmp/`basename $RPM` $RPM
			rpm -i --force /tmp/`basename $RPM`
		done
	fi
fi

SET_LIMIT_SH='/etc/elasticbeanstalk/set-ulimit.sh'
if ! cat /etc/sysconfig/docker | grep -q "$SET_LIMIT_SH"; then
	cat >> /etc/sysconfig/docker <<EOF
# Elastic Beanstalk
if [ -f $SET_LIMIT_SH ]; then
	. $SET_LIMIT_SH
fi

# we already took care of the ulimit settings, setting these two variables to blank
# so the init.d script doesn't override our changes
OPTIONS=
DAEMON_MAXFILES=
DATA_SIZE=99%FREE
AUTO_EXTEND_POOL=yes
LV_ERROR_WHEN_FULL=yes
EXTRA_DOCKER_STORAGE_OPTIONS="--storage-opt dm.fs=ext4"

EOF
fi

is_docker_storage_options_configured() {
	if [ -f /etc/sysconfig/docker-storage ]; then
		. /etc/sysconfig/docker-storage
	fi

	[ -n "$DOCKER_STORAGE_OPTIONS" ]
}

run_docker_storage_setup() {
	cat >> /etc/sysconfig/docker-storage-setup <<EOF
DEVS=$EB_CONFIG_DOCKER_VOLUME
VG=docker
EOF

	# if the device is already mounted, unmount it and docker-storage-setup will take care of the rest
	# in normal circumstannces this could only happen for ephemeral0 since cloud-init by default will mount it
	if [ -n "`lsblk -o MOUNTPOINT -nd $EB_CONFIG_DOCKER_VOLUME`" ]; then
		umount -f $EB_CONFIG_DOCKER_VOLUME
	fi

	# if docker-storage-setup we can still fall back to loopback
	# and appdeploy hooks will check the setup and give proper warnings
	docker-storage-setup || warn 'docker-storage-setup failed.'
}

EB_CONFIG_DOCKER_VOLUME=$(/opt/elasticbeanstalk/bin/get-config container -k docker_volume)

# only run docker-storage-setup once
if [ -b $EB_CONFIG_DOCKER_VOLUME ] && ! is_docker_storage_options_configured; then
	# stop docker and clean up /var/lib/docker (if docker was somehow started before this hook)
	service docker stop
	rm -rf /var/lib/docker

	run_docker_storage_setup
fi

# restart to make sure ulimit and storage changes are picked up
service docker restart
