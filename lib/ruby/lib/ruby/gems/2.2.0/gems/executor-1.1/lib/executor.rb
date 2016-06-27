require 'executor/exec'

module Executor
    # === Examples
    #
    #   require 'executor'
    #
    #   include Executor
    #   sh %[echo "hello"]                       # => "hello"
    #   sh %[false]                              # raises Executor::NonZeroExitStatus
    #
    # See Executor::Exec#sh for details
    def sh(*args, &block)
        exec = Exec.new
        exec.sh *args, &block
    end
end
