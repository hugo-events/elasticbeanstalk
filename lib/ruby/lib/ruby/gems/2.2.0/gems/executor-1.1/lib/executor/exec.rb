require 'timeout'

module Executor
    class NonZeroExitStatus < RuntimeError 
        attr_accessor :exit_code
        def initialize(msg:, exit_code:)
            super(msg)
            @exit_code = exit_code
        end
    end

    class Timeout < Timeout::Error; end

    # Executor#sh return value
    #
    # extends String with command, pid, exitstatus and time elapsed. to_s is the output of the command
    class Output < String
        attr_accessor :command, :exitstatus, :time_elapsed, :pid
    end

    # Library to execute shell commands
    class Exec
        include ::Timeout

        def initialize
        end

        # See Executor::Exec#sh
        def self.sh(*args, &block)
            exec = Exec.new
            exec.sh *args, &block
        end

        # execute shell command. returns Executor::Output
        #
        # === Examples
        #
        #   x = Executor::Exec.new
        #
        #   x.sh %Q[echo "hello"]                               # => "hello"
        #   x.sh %Q[echo "${X}"], :env => { 'X' => 'hello' }    # => "hello"
        #   x.sh %Q[sleep 2], :timeout => 1                     # raises Executor::Timeout
        #   x.sh %Q[false]                                      # raises Executor::NonZeroExitStatus
        #
        #   x.sh("true").exitstatus                             # => 0
        #   x.sh("false", :raise_on_error => false).exitstatus  # => 1
        #   x.sh("sleep 1").time_elapsed                        # => ~1
        #       
        # for tee(1) style live output:
        #
        #   Executor::Exec.sh("for x in 1 2 3; do echo $x; done") do |line|
        #       puts line
        #   end   # => 1\n2\n3
        #
        # === Attributes
        #
        # * +command+ executable command as a string
        # * +timeout+ timeout in seconds. set to 0 for unlimited. default is 0
        # * +raise_on_error+ if set to true Executor::NonZeroExitStatus is raised on non-zero exit status. default is true
        # * +chomp+ if set to true output is chomped. default is true
        # * +env+ hash of environment variables
        #
        # Executor::Exec is thread-safe
        #
        def sh(command, timeout: 0, raise_on_error: true, print_cmd_on_error: true,
                 chomp: true, env: default_env, &block)
            output = nil
    
            if ! timeout || timeout == 0
                # run the executable from the main thread
                output = exec command, :env => env, :block => block
            else
                begin
                    timeout(timeout) do
                        Thread.new {
                            output = exec command, :env => env, :block => block
                        }.value
                    end
                rescue ::Timeout::Error
                    raise Timeout, %[command timed out after #{timeout} seconds: #{command}]
                end
            end
            output.chomp! if chomp

            # raise error if command failed and raise_on_error is set        
            if output.exitstatus != 0 && raise_on_error
                err_msg = print_cmd_on_error ? %[#{output.command}\n#{output}] : output
                raise NonZeroExitStatus.new(msg: err_msg, exit_code: output.exitstatus)
            end

            return output
        end

        private
        def exec(command, env:, block: nil)
            output = ""

            time_start = Time.now
            IO.popen(env, command, :err => [:child, :out]) do |io|
                begin
                    lines = io.collect do |line|
                        block.call line if block
                        line
                    end

                    output = lines.join
                rescue Errno::EIO
                end
            end
            time_end = Time.now

            o = Output.new output
            o.command = command
            o.pid = $?.pid
            o.exitstatus = $?.exitstatus
            o.time_elapsed = time_end - time_start
            o
        end

        private
        def default_env
            @default_env ||= begin
                env_variables = %w[
                    GEM_HOME
                    GEM_PATH
                    GEM_ROOT
                    RUBIES
                    RUBYOPT
                    RUBY_ENGINE
                    RUBY_ROOT
                    RUBY_VERSION
                ]
                env_variables.inject({}) do |hash, key|
                    hash[key] = nil
                    hash
                end
            end
        end
    end
end
