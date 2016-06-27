require 'healthd/daemon/exceptions'

module Healthd
    module Plugins; end

    module Daemon
        module Plugins
            module Manager
                @@plugins = []
                @@versions = %w[1]
                @@metadata_key = 'healthd-plugin-version'
                @@exception_recovery_interval = 5

                def self.execute!
                    Logger.debug "#{self.name} initialized"

                    plugins = load :continue => block_given? ? Proc.new : nil
                    plugins.collect do |plugin|
                        Thread.new do
                            begin
                                plugin.collect
                            rescue Exceptions::PluginRuntimeError => e
                                Logger.warn e.message

                                sleep @@exception_recovery_interval
                                retry
                            rescue => e
                                Logger.error Healthd::Exceptions.format(e)

                                sleep @@exception_recovery_interval
                                retry
                            rescue Exception => e
                                Logger.fatal Healthd::Exceptions.format(e)
                                raise
                            end
                        end
                    end
                end

                def self.load(continue: nil)
                    @@plugins.collect do |plugin_module|
                        plugin = plugin_module.create :options  => Options.clone,
                                                      :continue => continue
                        plugin.setup
                        plugin
                    end
                end

                def self.locate_plugins(vendor: true)
                    specs = if vendor && Dir.exists?('vendor')
                        gem_spec_paths = Dir.glob("vendor/*/*.gemspec")
                        gem_spec_paths.collect { |path| Gem::Specification.load(path) }
                                      .select  { |spec| supported_plugin? spec }
                                      .each    { |spec| $LOAD_PATH << %[#{File.dirname(spec.loaded_from)}/lib] }
                    else
                        Gem::Specification.select { |spec| supported_plugin? spec }
                    end

                    specs.each { |spec| require spec.name }

                    plugin_modules = Healthd::Plugins.constants
                                                  .map(&Healthd::Plugins.method(:const_get))
                                                  .grep(Module)
                                                  .select { |m| m.public_methods.include? :create }

                    @@plugins.concat plugin_modules
                end

                def self.supported_plugin?(spec)
                    healthd_metadata = spec.metadata[@@metadata_key]
                    supported_plugin_version = @@versions.include? healthd_metadata
                    supported_platform = Gem::Platform.match spec.platform
                    supported = supported_plugin_version && supported_platform

                    case
                    when supported
                        Logger.debug %[#{spec.name} #{spec.version} is supported]
                    when healthd_metadata && !supported_plugin_version && !supported_platform
                        Logger.debug %[#{spec.name} #{spec.version} is not supported on this platform or daemon version. skipping]
                    when healthd_metadata && !supported_platform
                        Logger.debug %[#{spec.name} #{spec.version} is not supported on this platform. skipping]
                    when healthd_metadata && !supported_plugin_version
                        Logger.debug %[#{spec.name} #{spec.version} is not supported on this daemon version. skipping]
                    when healthd_metadata && !supported
                        Logger.debug %[#{spec.name} #{spec.version} is not supported. skipping]
                    end

                    supported
                end
            end
        end
    end
end
