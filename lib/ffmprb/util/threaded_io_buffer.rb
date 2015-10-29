module Ffmprb

  module Util

    # TODO the events mechanism is currently unused (and commented out) => synchro mechanism not needed
    # XXX *partially* specc'ed in file_spec
    class ThreadedIoBuffer
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
      #      the labdas must be timeout-interrupt-safe (since they are wrapped in timeout blocks)
      # NOTE both ios are being opened and closed as soon as possible
      def initialize(input, *outputs)  # XXX SPEC ME!!! multiple outputs!!

        @input = input
        @outputs = outputs.inject({}) do |hash, out|
          hash[out] = SizedQueue.new(self.class.blocks_max)
          hash
        end
        @stat_blocks_max = 0
        @terminate = false
        # @events = {}

        Thread.new "io buffer main" do
          init_reader!
          outputs.each do |output|
            init_writer_output! output
            init_writer! output
          end

          Thread.join_children!
        end
      end
      #
      # def once(event, &blk)
      #   event = event.to_sym
      #   wait_for_handler!
      #   if @events[event].respond_to? :call
      #     fail Error, "Once upon a time (one #once(event) at a time) please"
      #   elsif @events[event]
      #     Ffmprb.logger.debug "ThreadedIoBuffer (post-)reacting to #{event}"
      #     @handler_thr = Util::Thread.new "#{event} handler", &blk
      #   else
      #     Ffmprb.logger.debug "ThreadedIoBuffer subscribing to #{event}"
      #     @events[event] = blk
      #   end
      # end
      # handle_synchronously :once
      #
      # def reader_done!
      #   Ffmprb.logger.debug "ThreadedIoBuffer reader terminated (blocks max: #{@stat_blocks_max})"
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
      #   Ffmprb.logger.debug "ThreadedIoBuffer firing #{event}"
      #   if blk = @events.to_h[event.to_sym]
      #     @handler_thr = Util::Thread.new "#{event} handler", &blk
      #   end
      #   @events[event.to_sym] = true
      # end
      # handle_synchronously :fire!
      #
      def blocks_count
        @outputs.values.map(&:size).max
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

      def writer_output!(output)  # NOTE just for writer thread
        if @output_thrs[output]
          @output_thrs[output].join
          @output_thrs[output] = nil
        end
        @output_ios[output]
      end

      # NOTE reads all of input, then closes the stream times out on buffer overflow
      def init_reader!
        Thread.new("buffer reader") do
          begin
            while s = reader_input!.read(self.class.block_size)
              begin
                Timeout.timeout(self.class.timeout) do
                  output_enq s
                end
              rescue Timeout::Error  # NOTE the queue is probably overflown
                @terminate = Error.new("The reader has failed with timeout while queuing")
                # timeout!
                fail Error, "Looks like we're stuck (#{timeout}s idle) with #{self.class.blocks_max}x#{self.class.block_size}B blocks (buffering #{reader_input!.path}->...)..."
              end
              @stat_blocks_max = blocks_count  if blocks_count > @stat_blocks_max
            end
            @terminate = true
            output_enq nil
          ensure
            begin
              reader_input!.close  if reader_input!.respond_to?(:close)
            rescue
              Ffmprb.logger.error "ThreadedIoBuffer input closing error: #{$!.message}"
            end
            # reader_done!
            Ffmprb.logger.debug "ThreadedIoBuffer reader terminated (blocks max: #{@stat_blocks_max})"
          end
        end
      end

      def init_writer_output!(output)
        @output_ios ||= {}
        return @output_ios[output] = output  unless output.respond_to?(:call)

        @output_thrs ||= {}
        @output_thrs[output] = Thread.new("buffer writer output helper") do
          Ffmprb.logger.debug "Opening buffer output"
          @output_ios[output] =
            Thread.timeout_or_live nil, log: "in the buffer writer helper thread", timeout: self.class.timeout do |time|
              fail Error, "giving up buffer writer init since the reader has failed (#{@terminate.message})"  if @terminate.kind_of?(Exception)
              output.call
            end
          Ffmprb.logger.debug "Opened buffer output: #{@output_ios[output].path}"
        end
      end

      # NOTE writes as much output as possible, then terminates when the reader dies
      def init_writer!(output)
        Thread.new("buffer writer") do
          broken = false
          begin
            while s = @outputs[output].deq
              next  if broken
              written = 0
              tries = 1
              logged_tries = 1/2
              while !broken
                fail @terminate  if @terminate.kind_of?(Exception)
                begin
                  output_io = writer_output!(output)
                  written = output_io.write_nonblock(s)  if output  # NOTE will only be nil if @terminate is an exception
                  break  if written == s.length  # NOTE kinda optimisation
                  s = s[written..-1]
                rescue Errno::EAGAIN, Errno::EWOULDBLOCK
                  if tries == 2 * logged_tries
                    Ffmprb.logger.debug "ThreadedIoBuffer writer (to #{output_io.path}) retrying... (#{tries} writes): #{$!.class}"
                    logged_tries = tries
                  end
                  sleep 0.01
                rescue Errno::EPIPE
                  broken = true
                  Ffmprb.logger.debug "ThreadedIoBuffer writer (to #{output_io.path}) broken"
                ensure
                  tries += 1
                end
              end
            end
          ensure
            # terminated!
            begin
              writer_output!(output).close  if !broken && writer_output!(output).respond_to?(:close)
            rescue
              Ffmprb.logger.error "ThreadedIoBuffer output closing error: #{$!.message}"
            end
            Ffmprb.logger.debug "ThreadedIoBuffer writer terminated (blocks max: #{@stat_blocks_max})"
          end
        end
      end
      #
      # def wait_for_handler!
      #   @handler_thr.join  if @handler_thr
      #   @handler_thr = nil
      # end

      def output_enq(item)
        @outputs.values.each do |q|
          q.enq item
        end
      end

    end

  end

end
