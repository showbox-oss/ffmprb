require 'ostruct'

module Ffmprb

  module Util

    # TODO the events mechanism is currently unused (and commented out) => synchro mechanism not needed
    class ThreadedIoBuffer
      include MonitorMixin
      # XXX include Synchro
      include ProcVis::Node

      IO_WAIT_DELAY = 0.01

      class << self

        attr_accessor :blocks_max
        attr_accessor :block_size
        attr_accessor :timeout
        attr_accessor :timeout_limit

      end

      # NOTE input/output can be lambdas for single asynchronic io evaluation
      #      the lambdas must be timeout-interrupt-safe (since they are wrapped in timeout blocks)
      # NOTE all ios are being opened and closed as soon as possible
      def initialize(input, *outputs)
        super()  # NOTE for the monitor, apparently

        Ffmprb.logger.debug "ThreadedIoBuffer initializing with (#{ThreadedIoBuffer.blocks_max}x#{ThreadedIoBuffer.block_size})"

        @input = input
        @outputs = outputs.map do |outp|
          OpenStruct.new _io: outp, q: SizedQueue.new(ThreadedIoBuffer.blocks_max)
        end
        @stats = {blocks_max: 0, bytes_in: 0, bytes_out: 0}
        @terminate = false
        # @events = {}

        Thread.new "io buffer main" do
          init_reader!
          @outputs.each do |output|
            init_writer_output! output
            init_writer! output
          end

          Thread.join_children!.tap do
            Ffmprb.logger.debug "ThreadedIoBuffer (#{@input.path}->#{@outputs.map(&:io).map(&:path)}) terminated successfully (#{@stats})"
          end
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
      #   Ffmprb.logger.debug "ThreadedIoBuffer reader terminated (#{@stats})"
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

      # protected
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

      private

      class AllOutputsBrokenError < Error
      end

      def reader_input!  # NOTE just for reader thread
        if @input.respond_to?(:call)
          Ffmprb.logger.debug "Opening buffer input"
          @input = @input.call
          Ffmprb.logger.debug "Opened buffer input: #{@input.path}"
        end
        @input
      end

      # NOTE to be called after #init_writer_output! only
      def writer_output!(output)  # NOTE just for writer thread
        if output.thr
          output.thr.join
          output.thr = nil
        end
        output.io
      end

      # NOTE reads roughly as much input as writers can write, then closes the stream; times out on buffer overflow
      def init_reader!
        Thread.new("buffer reader") do
          begin
            while s = reader_input!.read(ThreadedIoBuffer.block_size)
              synchronize do
                @stats[:bytes_in] += s.length
              end
              output_enq! s
            end
            @terminate = true
            output_enq! nil  # NOTE EOF signal
          rescue AllOutputsBrokenError
            Ffmprb.logger.info "All outputs broken"
          ensure
            begin
              reader_input!.close  if reader_input!.respond_to?(:close)
            rescue
              Ffmprb.logger.error "#{$!.class.name} closing ThreadedIoBuffer input: #{$!.message}"
            end
            # reader_done!
            Ffmprb.logger.debug "ThreadedIoBuffer reader terminated (#{@stats})"
          end
        end
      end

      def init_writer_output!(output)
        return output.io = output._io  unless output._io.respond_to?(:call)

        output.thr = Thread.new("buffer writer output helper") do
          Ffmprb.logger.debug "Opening buffer output"
          output.io =
            Thread.timeout_or_live nil, log: "in the buffer writer helper thread", timeout: ThreadedIoBuffer.timeout do |time|
              fail Error, "giving up buffer writer init since the reader has failed (#{@terminate.message})"  if @terminate.kind_of? Exception
              output._io.call
            end
          Ffmprb.logger.debug "Opened buffer output: #{output.io.path}"
        end
      end

      # NOTE writes as much output as possible, then terminates when the reader dies
      def init_writer!(output)
        Thread.new("buffer writer") do
          begin
            while s = output.q.deq  # NOTE until EOF signal
              written = 0
              tries = 0
              logged_tries = 1/2
              begin
                tries += 1
                fail @terminate  if @terminate.kind_of? Exception
                output_io = writer_output!(output)
                written = output_io.write_nonblock(s)  if output_io  # NOTE will only be nil if @terminate is an exception
                synchronize do
                  @stats[:bytes_out] += written
                end

                if written != s.length  # NOTE kinda optimisation
                  s = s[written..-1]
                  raise IO::EAGAINWaitWritable
                end

              rescue IO::WaitWritable
                if tries == 2 * logged_tries
                  Ffmprb.logger.debug "ThreadedIoBuffer writer (to #{output_io.path}) retrying... (#{tries} writes): #{$!.class}"
                  logged_tries = tries
                end
                sleep IO_WAIT_DELAY
                retry
              rescue Errno::EPIPE
                output.broken = true
                Ffmprb.logger.debug "ThreadedIoBuffer writer (to #{output_io.path}) broken"
                break
              end
            end
          ensure
            # terminated!
            begin
              writer_output!(output).close  if !output.broken && writer_output!(output).respond_to?(:close)
            rescue
              Ffmprb.logger.error "#{$!.class.name} closing ThreadedIoBuffer output: #{$!.message}"
            end
            Ffmprb.logger.debug "ThreadedIoBuffer writer (to #{output_io && output_io.path}) terminated (#{@stats})"
          end
        end
      end
      #
      # def wait_for_handler!
      #   @handler_thr.join  if @handler_thr
      #   @handler_thr = nil
      # end

      def output_enq!(item)
        fail AllOutputsBrokenError  if
          @outputs.select do |output|
            next  if output.broken

            timeouts = 0
            begin
              # NOTE let's assume there's no race condition here between the possible timeout exception and enq
              Timeout.timeout(ThreadedIoBuffer.timeout) do
                output.q.enq item
              end
              blocks = output.q.length
              synchronize do
                @stats[:blocks_max] = blocks  if blocks > @stats[:blocks_max]
              end
              true

            rescue Timeout::Error
              next  if output.broken

              timeouts += 1
              Ffmprb.logger.warn "A little bit of timeout (>#{timeouts*ThreadedIoBuffer.timeout}s idle) with #{ThreadedIoBuffer.blocks_max}x#{ThreadedIoBuffer.block_size}b blocks (buffering #{reader_input!.path}->...; #{@outputs.reject(&:io).size}/#{@outputs.size} unopen/total)"

              retry  unless timeouts >= ThreadedIoBuffer.timeout_limit # NOTE the queue has probably overflown

              @terminate = Error.new("the writer has failed with timeout limit while queuing")
              # timeout!
              fail Error, "Looks like we're stuck (>#{ThreadedIoBuffer.timeout_limit*ThreadedIoBuffer.timeout}s idle) with #{ThreadedIoBuffer.blocks_max}x#{ThreadedIoBuffer.block_size}b blocks (buffering #{reader_input!.path}->...)..."
            end
        end.empty?
      end

    end

  end

end
