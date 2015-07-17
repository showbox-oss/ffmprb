module Ffmprb

  module Util

    # NOTE doesn't have specs (and not too proud about it)
    class Thread < ::Thread

      def initialize(name="some", &blk)
        super() do
          begin
            Ffmprb.logger.debug "#{name} thread launched"
            blk.call
            Ffmprb.logger.debug "#{name} thread done"
          rescue Exception
            Ffmprb.logger.warn "#{$!.class} caught in a #{name} thread (hidden): #{$!.message}\nBacktrace:\n\t#{$!.backtrace.join("\n\t")}"
            cause = $!
            Ffmprb.logger.warn "...caused by #{cause.class}: #{cause.message}\nBacktrace:\n\t#{cause.backtrace.join("\n\t")}" while
              cause = cause.cause
            raise
          end
        end
      end

    end

  end

end
