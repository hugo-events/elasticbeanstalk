# Beanstalk

#==============================================================================
# Copyright 2014 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the "License"). You may not use
# this file except in compliance with the License. A copy of the License is
# located at
#
#       https://aws.amazon.com/asl/
#
# or in the "license" file accompanying this file. This file is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
# implied. See the License for the specific language governing permissions
# and limitations under the License.
#==============================================================================
require 'fileutils'

require 'elasticbeanstalk/container-config-manager'

config_manager = ElasticBeanstalk::ContainerConfigManager.new
staging_dir = config_manager.container_config('app_staging_dir')

if staging_dir && Dir.exists?(staging_dir)
    FileUtils.rm_rf(Dir["#{staging_dir}/**/.ebextensions"])    
    "Cleaned ebextensions subdirectories from #{staging_dir}."
else     
    'Cannot find app staging directory. Skipping ebextensions cleanup.'
end

