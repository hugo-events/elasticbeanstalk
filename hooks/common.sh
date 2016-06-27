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

trace() {
  echo "$1" # echo so it will be captured by logs
  eventHelper.py --msg "$1" --severity TRACE || true
}

warn() {
  echo "$1" # echo so it will be captured by logs
  eventHelper.py --msg "$1" --severity WARN || true
}

error() {
  echo "$1" # echo so it will be captured by logs
  eventHelper.py --msg "$1" --severity ERROR || true
}

error_exit() {
  error "$1"
  exit $2
}

is_baked() {
  if [[ -f /etc/elasticbeanstalk/baking_manifest/$1 ]]; then
    true
  else
    false
  fi
}

save_docker_image_names() {
  docker images | sed 1d | awk '{print "docker tag -f", $3, "\""$1":"$2"\""}' > /tmp/restore_docker_image_names.sh
  chmod +x /tmp/restore_docker_image_names.sh
}

restore_docker_image_names() {
  /tmp/restore_docker_image_names.sh || true
}
