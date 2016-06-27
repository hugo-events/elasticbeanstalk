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
require 'json'

msg = []

FileUtils.rm_rf(Command.deploy_config_dir)
FileUtils.mkdir_p(Command.deploy_config_dir)
msg << "Recreated directory #{Command.deploy_config_dir}."


env_metadata = EnvironmentMetadata.new

appsource_url = env_metadata.app_source_url
File.open(Command.appsourceurl_file, 'w') do |f|
    content = JSON.pretty_generate({'url' => appsource_url})
    f.write(content)
end
msg << "Generate appsource url file at #{Command.appsourceurl_file}."


container_config = env_metadata.container_config
File.open(Command.containerconfig_file, 'w') { |f| f.write(container_config.to_json) }

Utils.set_eb_datafile_permission(Command.containerconfig_file)

msg << "Generate container config file at #{Command.containerconfig_file}."

msg.join("\n")
