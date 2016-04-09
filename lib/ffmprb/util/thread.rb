module Ffmprb

  module Util

    # NOTE doesn't have specs (and not too proud about it)
    class Thread < ::Thread

      class Error < Ffmprb::Error; end
      class ParentError < Error; end

      class << self

        attr_accessor :timeout

        def timeout_or_live(limit=nil, log: "while doing this", timeout: self.timeout, &blk)
          started_at = Time.now
          tries = 0
          logged_tries = 0
          begin
            tries += 1
            time = Time.now - started_at
            fail TimeLimitError  if limit && time > limit
            Timeout.timeout timeout do
              blk.call time
            end
          rescue Timeout::Error
            if tries > 2 * logged_tries
              Ffmprb.logger.info "A little bit of timeout #{log.respond_to?(:call)? log.call : log} (##{tries})"
              logged_tries = tries
            end
            current.live!
            retry
          end
        end

        def join_children!(limit=nil, timeout: self.timeout)
          Thread.current.join_children! limit, timeout: timeout
        end

      end

      attr_reader :name

      def initialize(name="some", &blk)
        @name = name
        @parent = Thread.current
        @live_children = []
        @children_mon = Monitor.new
        @dead_children_q = Queue.new
        Ffmprb.logger.debug "about to launch #{name}"
        sync_q = Queue.new
        super() do
          @parent.child_lives self  if @parent.respond_to? :child_lives
          sync_q.enq :ok
          Ffmprb.logger.debug "#{name} thread launched"
          begin
            blk.call.tap do
              Ffmprb.logger.debug "#{name} thread done"
            end
          rescue Exception
            Ffmprb.logger.warn "#{$!.class.name} raised in #{name} thread: #{$!.message}\nBacktrace:\n\t#{$!.backtrace.join("\n\t")}"
            cause = $!
            Ffmprb.logger.warn "...caused by #{cause.class.name}: #{cause.message}\nBacktrace:\n\t#{cause.backtrace.join("\n\t")}" while
              cause = cause.cause
            fail $!  # XXX I have no idea why I need to give it `$!` -- the docs say I need not
          ensure
            @parent.child_dies self  if @parent.respond_to? :child_dies
          end
        end
        sync_q.deq
      end

      # TODO protected: none of these methods should be called by a user code, the only public methods are above

      def live!
        fail ParentError  if @parent.status.nil?
      end

      def child_lives(thr)
        @children_mon.synchronize do
          Ffmprb.logger.debug "picking up #{thr.name} thread"
          @live_children << thr
        end
      end

      def child_dies(thr)
        @children_mon.synchronize do
          Ffmprb.logger.debug "releasing #{thr.name} thread"
          @dead_children_q.enq thr
          fail "System Error"  unless @live_children.delete thr
        end
      end

      def join_children!(limit=nil, timeout: self.class.timeout)
        timeout = [timeout, limit].compact.min
        Ffmprb.logger.debug "joining threads: #{@live_children.size} live, #{@dead_children_q.size} dead"
        until @live_children.empty? && @dead_children_q.empty?
          thr = self.class.timeout_or_live limit, log: "joining threads: #{@live_children.size} live, #{@dead_children_q.size} dead", timeout: timeout do
            @dead_children_q.deq
          end
          Ffmprb.logger.debug "joining the late #{thr.name} thread"
          fail "System Error"  unless thr.join(timeout)  # NOTE should not block
        end
      end

    end

  end

end
