module Ffmprb

  module Util

    # XXX the events mechanism is currently unused (and commented out) => synchro mechanism not needed
    # XXX partially specc'ed in file_spec
    class IoBuffer
      # include Synchro

      class << self

        attr_accessor :blocks_max
        attr_accessor :block_size
        attr_accessor :timeout

        def default_size
          blocks_max * block_size
        end

      end

      # NOTE input/output can be lambdas for single asynchronic io evaluation
      # NOTE both ios are closed as soon as possible
      def initialize(input, output,
        blocks_max: self.class.blocks_max, block_size: self.class.block_size)

        @input = input
        @output = output
        @q = SizedQueue.new(blocks_max)
        @stat_blocks_max = 0
        @terminate = false
        # @events = {}

        # NOTE reads all of input, then closes the stream times out on buffer overflow

        @reader = Util::Thread.new("buffer reader") do
          begin
            while s = reader_input!.read(block_size)
              begin
                Timeout::timeout(self.class.timeout) do
                  @q.enq s
                end
              rescue Timeout::Error  # NOTE the queue is probably overflown
                @terminate = Error.new("The reader has failed with timeout while queuing")
                # timeout!
                raise Error, "Looks like we're stuck (#{self.class.timeout}s idle) with #{blocks_max}x#{block_size}B blocks (buffering #{reader_input!.path}->...)..."
              end
              @stat_blocks_max = blocks_count  if blocks_count > @stat_blocks_max
            end
            @terminate = true
            @q.enq nil
          ensure
            begin
              reader_input!.close  if reader_input!.respond_to?(:close)
            rescue
              Ffmprb.logger.error "IoBuffer input closing error: #{$!.message}"
            end
            # reader_done!
            Ffmprb.logger.debug "IoBuffer reader terminated (blocks max: #{@stat_blocks_max})"
          end
        end

        init_writer_output!

        # NOTE writes as much output as possible, then terminates when the reader dies

        @writer = Util::Thread.new("buffer writer") do
          broken = false
          begin
            while s = @q.deq
              next  if broken
              written = 0
              while !broken
                raise @terminate  if @terminate.kind_of?(Exception)
                begin
                  output = writer_output!
                  written = output.write_nonblock(s)  if output  # NOTE will only be nil if @terminate is an exception
                  break  if written == s.length  # NOTE kinda optimisation
                  s = s[written..-1]
                rescue Errno::EAGAIN
                  Ffmprb.logger.debug "IoBuffer writer (to #{output.path}) retrying"
                  sleep 0.01
                rescue Errno::EWOULDBLOCK
                  Ffmprb.logger.debug "IoBuffer writer (to #{output.path}) taking a break"
                  sleep 0.01
                rescue Errno::EPIPE
                  broken = true
                  Ffmprb.logger.debug "IoBuffer writer (to #{output.path}) broken"
                end
              end
            end
          ensure
            # terminated!
            begin
              writer_output!.close  if !broken && writer_output!.respond_to?(:close)
            rescue
              Ffmprb.logger.error "IoBuffer output closing error: #{$!.message}"
            end
            Ffmprb.logger.debug "IoBuffer writer terminated (blocks max: #{@stat_blocks_max})"
          end
        end
      end

      def flush!  # NOTE blocking, closes ios
        e = nil
        # [@reader, @writer, @handler_thr].each do |thr|
        [@reader, @writer, @output_thr].compact.each do |thr|
          begin
            thr.join
          rescue
            if e
              Ffmprb.logger.debug "Additionally got (hidden): #{$!.message}"
            else
              e = $!
            end
          end
        end
        raise e  if e
      end
      # handle_synchronously :flush!
      #
      # def once(event, &blk)
      #   event = event.to_sym
      #   wait_for_handler!
      #   if @events[event].respond_to? :call
      #     raise Error, "Once upon a time (one #once(event) at a time) please"
      #   elsif @events[event]
      #     Ffmprb.logger.debug "IoBuffer (post-)reacting to #{event}"
      #     @handler_thr = Util::Thread.new "#{event} handler", &blk
      #   else
      #     Ffmprb.logger.debug "IoBuffer subscribing to #{event}"
      #     @events[event] = blk
      #   end
      # end
      # handle_synchronously :once
      #
      # def reader_done!
      #   Ffmprb.logger.debug "IoBuffer reader terminated (blocks max: #{@stat_blocks_max})"
      #   fire! :reader_done
      # end
      #
      # def terminated!
      #   fire! :terminated
      # end
      #
      # def timeout!
      #   fire! :timeout
      # end

      protected
      #
      # def fire!(event)
      #   wait_for_handler!
      #   Ffmprb.logger.debug "IoBuffer firing #{event}"
      #   if blk = @events.to_h[event.to_sym]
      #     @handler_thr = Util::Thread.new "#{event} handler", &blk
      #   end
      #   @events[event.to_sym] = true
      # end
      # handle_synchronously :fire!
      #
      def blocks_count
        @q.size
      end

      private

      def reader_input!  # NOTE just for reader thread
        if @input.respond_to?(:call)
          Ffmprb.logger.debug "Opening buffer input"
          @input = @input.call
          Ffmprb.logger.debug "Opened buffer input: #{@input.path}"
        end
        @input
      end

      def writer_output!  # NOTE just for writer thread
        if @output_thr
          @output_thr.join
          @output_thr = nil
        end
        @output  unless @output.respond_to?(:call)
      end

      def init_writer_output!
        return  unless @output.respond_to?(:call)

        @output_thr = Util::Thread.new("buffer writer output helper") do
          Ffmprb.logger.debug "Opening buffer output"
          begin
            Timeout::timeout(self.class.timeout/2) do
              @output = @output.call
              Ffmprb.logger.debug "Opened buffer output: #{@output.path}"
            end
          rescue Timeout::Error
            Ffmprb.logger.info "A little bit of timeout in the buffer writer helper thread"
            retry  unless @terminate.kind_of?(Exception)
          end
        end
      end
      #
      # def wait_for_handler!
      #   @handler_thr.join  if @handler_thr
      #   @handler_thr = nil
      # end

    end

  end

end
