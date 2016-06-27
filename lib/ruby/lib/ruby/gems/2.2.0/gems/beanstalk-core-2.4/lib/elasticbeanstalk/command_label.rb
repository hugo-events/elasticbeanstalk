
module ElasticBeanstalk
    module CommandLabel

        @@labels = {
            "CMD-PreInit"       =>  {
                0   =>  "Initialization".freeze
            },
            "CMD-Startup"       =>  {
                0   =>  "Application deployment".freeze,
                1   =>  "Application deployment".freeze,
            },
            "CMD-SelfStartup"   =>  {
                0   =>  "Application deployment".freeze,
                1   =>  "Application deployment".freeze,
            },
            "CMD-AppDeploy"   =>  {
                0   =>  "Application update".freeze,
                1   =>  "Application version switch".freeze,
            },
            "CMD-ConfigDeploy"   =>  {
                0   =>  "Configuration update".freeze,
                1   =>  "Application restart".freeze,
            },
            "CMD-SqsdDeploy"   =>  {
                0   =>  "Configuration update".freeze
            },
            "CMD-RestartAppServer"   =>  {
                0   =>  "Application restart".freeze,
                1   =>  "Application restart".freeze,
            },
            "CMD-ImmutableDeploymentFlip"   =>  {
                0   =>  'Re-associating instance'.freeze
            },
        }

        @@deployment_commands = %w[CMD-Startup CMD-SelfStartup CMD-AppDeploy CMD-ConfigDeploy]

        def self.for_name(name, stage:)
            index ||= stage.to_i

            if @@labels[name] && @@labels[name][index]
                return @@labels[name][index]
            end

            # fallback
            default_label(name: name, stage: stage)
        rescue
            default_label(name: name, stage: stage)
        end

        def self.wait_for_next_command?(name, stage:)
            case
            when name == 'CMD-PreInit'
                true
            when @@labels[name].nil? || stage.nil?
                false
            when @@labels[name][stage.to_i].nil?
                false
            when stage.to_i < (@@labels[name].size-1)
                true
            else
                false
            end
        end

        def self.deployment_tag(name:, version_label:nil, deployment_id:nil)
            if is_deployment?(name) && version_label && deployment_id
                "#{version_label}@#{deployment_id}"
            else
                nil
            end
        rescue
            # not fatal
            nil
        end

        private
        def self.default_label(name:, stage:)
           stage ? "#{name} - stage #{stage}" : "#{name}"
        end

        private
        def self.is_deployment?(name)
            @@deployment_commands.include?(name)
        end
    end
end
