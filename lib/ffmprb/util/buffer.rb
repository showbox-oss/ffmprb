module Ffmprb

  module Util

    # XXX partially specc'ed in file_spec
    class Buffer
      include Synchro

      class << self

        attr_accessor :default_blocks_max
        attr_accessor :default_block_size
        attr_accessor :default_timeout

        def default_size
          default_blocks_max * default_block_size
        end

      end

      attr_reader :input, :output  # NOTE IOs

      def initialize(input, output,
        blocks_max: self.class.default_blocks_max, block_size: self.class.default_block_size)

        @input = input
        @output = output
        @q = SizedQueue.new(blocks_max)
        @stat_blocks_max = 0
        @terminate = false

        # NOTE reads all of input, times out on buffer overflow

        @reader = Thread.new("buffer reader (from #{input.path})") do
          begin
            while s = input.read(block_size)
              begin
                Timeout::timeout(self.class.default_timeout) do
                  @q.enq s
                end
              rescue Timeout::Error  # NOTE the queue is probably overflown
                @terminate = Error.new("The reader has failed with timeout while queuing")
                timeout!
                raise Error, "Looks like we're stuck (#{self.class.default_timeout}s idle) with #{blocks_max}x#{block_size}B blocks (buffering #{input.path}->#{output.path})..."
              end
              @stat_blocks_max = blocks_count  if blocks_count > @stat_blocks_max
            end
            @terminate = true
            @q.enq nil
          ensure
            reader_done!
          end
        end

        # NOTE writes as much output as possible, then terminates when the reader dies

        @writer = Thread.new("buffer writer (to #{output.path})") do
          broken = false
          begin
            while s = @q.deq
              next  if broken
              written = 0
              loop do
                s = s[written..-1]
                begin
                  break  if output.write_nonblock(s) == s.length
                rescue IO::WaitWritable
                  raise @terminate  if @terminate.kind_of?(Exception)
                  sleep 0.01
                rescue Errno::EPIPE
                  broken = true
                  Ffmprb.logger.debug "Buffer writer (to #{output.path}) broken"
                  break
                end
              end
            end
          ensure
            terminated!
          end
        end
      end

      # XXX YAGNI?
      def flush  # NOTE blocking
        reader.join
        writer.join
      end

      def once(event, &blk)
        @events ||= {}
        event = event.to_sym
        if @events[event].respond_to? :call
          raise Error, "Once upon a time (one #once(event) at a time) please"
        elsif @events[event]
          Ffmprb.logger.debug "Buffer (#{input.path} -> #{output.path}) (post-)reacting to #{event}"
          Thread.new "#{event} handler", &blk
        else
          Ffmprb.logger.debug "Buffer (#{input.path} -> #{output.path}) (post-)reacting to #{event}"
          @events[event] = blk
        end
      end
      handle_synchronously :once

      def reader_done!
        Ffmprb.logger.debug "Buffer reader (from #{input.path}) terminated (blocks max: #{@stat_blocks_max})"
        fire! :reader_done
      end

      def terminated!
        fire! :terminated
      end

      def timeout!
        fire! :timeout
      end

      protected

      def fire!(event)
        Ffmprb.logger.debug "Buffer (#{input.path} -> #{output.path}) firing #{event}"
        if blk = @events.to_h[event.to_sym]
          Thread.new "#{event} handler", &blk
        end
        @events[event.to_sym] = true
      end
      handle_synchronously :fire!

      def blocks_count
        @q.size
      end

    end

  end

end
